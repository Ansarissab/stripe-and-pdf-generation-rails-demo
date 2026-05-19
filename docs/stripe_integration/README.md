# Stripe + Pay + Rails 8.1 — integration runbook

Everything we hit setting this demo up, why it happened, and how to fix it. Order is from "first thing you'll trip on" to "deep gotchas you hit after the happy path works."

- [1. Stack & moving parts](#1-stack--moving-parts)
- [2. Stripe dashboard setup (one-time)](#2-stripe-dashboard-setup-one-time)
- [3. Environment variables](#3-environment-variables)
- [4. Local development loop](#4-local-development-loop)
- [5. Webhooks: CLI vs dashboard endpoint](#5-webhooks-cli-vs-dashboard-endpoint)
- [6. Two checkout flows](#6-two-checkout-flows)
- [7. Sync model: Stripe → Pay → users.plan](#7-sync-model-stripe--pay--usersplan)
- [8. Operations: orphan subs, resync, flush](#8-operations-orphan-subs-resync-flush)
- [9. Troubleshooting — every error we hit, in order](#9-troubleshooting--every-error-we-hit-in-order)
- [10. Production checklist (Kamal)](#10-production-checklist-kamal)

---

## 1. Stack & moving parts

| Layer | Tool | Version pinned | Role |
|---|---|---|---|
| Auth | Devise | 5.0.4 | Sign-up / sign-in / confirmation |
| Authorization | Pundit | 2.5.2 | Per-action policies under `app/policies/` |
| Billing wrapper | Pay gem | 11.6.1 | Wraps Stripe SDK, persists `Pay::Customer`, `Pay::Subscription`, `Pay::Charge`, `Pay::Webhook` |
| Stripe SDK | stripe-ruby | 19.1.0 | Talks to Stripe API |
| PDF | HexaPDF | 1.8.0 | Pure-Ruby invoice generation |
| Frontend | Hotwire + Stimulus + Tailwind v4 | — | Including a Stimulus controller that wraps Stripe Elements |
| Tunnel (dev) | Tailscale Funnel | — | Public HTTPS URL for production-style webhook testing |
| Webhook delivery (dev) | Stripe CLI | — | `stripe listen` forwards events from Stripe to localhost |

Key model relations:

```
User
 └─ has_many :pay_customers  (Pay::Customer, STI subclass Pay::Stripe::Customer)
      ├─ has_many :subscriptions  (Pay::Subscription → Pay::Stripe::Subscription)
      ├─ has_many :charges        (Pay::Charge       → Pay::Stripe::Charge)
      └─ has_many :payment_methods
```

`users.plan` is a **cached** integer enum (`basic` / `pro`). The source of truth is `Pay::Subscription`; we mirror it for fast badge lookups via the [`PlanSync` concern](../../app/models/concerns/plan_sync.rb).

---

## 2. Stripe dashboard setup (one-time)

1. Switch the dashboard to **Test mode** (toggle top-right).
2. **Products** → create two:
   - `Basic`, recurring, e.g. `$9.99 USD / month`. Save → copy the **Price ID** (`price_...`). That becomes `PAY_STRIPE_PLAN_BASIC`.
   - `Pro`, recurring, e.g. `$29.99 USD / month`. Save → copy the Price ID. That becomes `PAY_STRIPE_PLAN_PRO`.
3. **Developers → API keys**:
   - Publishable key (`pk_test_...`) → `STRIPE_PUBLIC_KEY`
   - Secret key (`sk_test_...`) → `STRIPE_PRIVATE_KEY` (note: Pay's naming, not Stripe's "Secret key" label)
4. **Settings → Billing → Customer portal**:
   - Click **Activate test link**
   - Tick *"Customers can switch plans"*, *"Customers can cancel subscriptions"*
   - Add both prices to the allowed switching list
   - Save
   - Without this step, `POST /account/subscription/billing_portal` returns a Stripe error.

Don't create a dashboard webhook endpoint for local dev — use `stripe listen` instead (§5).

---

## 3. Environment variables

Source of truth: [.env.example](../../.env.example). Copy to `.env` (gitignored).

```sh
STRIPE_PUBLIC_KEY=pk_test_...
STRIPE_PRIVATE_KEY=sk_test_...
STRIPE_SIGNING_SECRET=whsec_...      # from `stripe listen`, NOT the dashboard
PAY_STRIPE_PLAN_BASIC=price_...
PAY_STRIPE_PLAN_PRO=price_...
PORT=3200
SECRET_KEY_BASE=...
```

**Naming pitfall**: Stripe's dashboard labels these as `Secret key` and `Signing secret`. Pay's runtime reads `STRIPE_PRIVATE_KEY` and `STRIPE_SIGNING_SECRET`. We renamed at commit `60ce487` to drop the bridging code. If you copy from the dashboard, **rename** to match — otherwise Pay throws `Stripe::AuthenticationError`.

**`APP_HOST` is NOT used by the app.** Earlier drafts tried to override redirect URLs with it; the right model is `request.base_url` because Stripe-bound URLs are followed by the user's browser, not by Stripe servers. Setting `APP_HOST` forces a host swap mid-flow (start on localhost → redirected to tunnel) which is almost never what you want. We removed the dependency at the controller level. See pitfall §9.10.

---

## 4. Local development loop

Three processes, three terminals:

```sh
# Terminal 1 — Rails + Tailwind watcher (bin/dev defaults PORT to 3200)
bin/dev

# Terminal 2 — Stripe CLI: forwards real Stripe test-mode webhooks to your localhost
stripe listen --forward-to localhost:3200/pay/webhooks/stripe
# This prints `whsec_...` -- copy to STRIPE_SIGNING_SECRET in .env, restart `bin/dev`.

# Terminal 3 (optional) — Tailscale Funnel: public HTTPS URL pointing at :3200
tailscale funnel 3200
# Gives you something like https://machine.taile00403.ts.net
# Useful when demoing from another device or when you want to register a real
# webhook endpoint in the Stripe dashboard (production-style).
```

Devise emails (sign-up confirmation, password reset) go to **letter_opener_web** in dev — visit http://localhost:3200/letter_opener to read them. Confirmable users can't sign in until they click the confirmation link.

For a hot start with confirmed users:

```sh
bin/rails db:seed   # creates nobody@example.test, basic@example.test, pro@example.test (password: password)
```

---

## 5. Webhooks: CLI vs dashboard endpoint

You almost never want both running at once — they deliver the same events and you'll process each event twice.

| Scenario | Use |
|---|---|
| Local dev, single machine | `stripe listen` only. The CLI's `whsec_...` goes in `.env`. |
| Demoing through tunnel from another device | Stripe Dashboard endpoint pointing at the tunnel URL. Stop `stripe listen`. Swap the dashboard's signing secret into `.env`. |
| Production | Stripe Dashboard endpoint pointing at the deployed URL. The dashboard's signing secret lives in Kamal's `.kamal/secrets`. |

**Dashboard endpoint setup** (only when you actually need it):

1. https://dashboard.stripe.com/test/webhooks → **Add endpoint**
2. URL: `https://your-host/pay/webhooks/stripe` (the URL is auto-mounted by Pay; see `config/initializers/pay.rb`)
3. Events (minimum for Pay + our `PlanSync` to work end-to-end):
   - `customer.subscription.created`
   - `customer.subscription.updated`
   - `customer.subscription.deleted`
   - `invoice.paid`
   - `invoice.payment_failed`
   - `invoice.finalized`
   - `charge.succeeded`
   - `charge.refunded`
   - `checkout.session.completed`
   - `payment_intent.created`
   - `payment_intent.succeeded`
   - `payment_intent.payment_failed`
4. Save → reveal **Signing secret** → that's the new `STRIPE_SIGNING_SECRET`.

---

## 6. Two checkout flows

We expose both Stripe-native flows so the demo can show off either:

| Flow | Route | UX | What Stripe gets called |
|---|---|---|---|
| **Hosted Checkout** | `POST /account/subscription?plan=basic` | User is redirected to `checkout.stripe.com`, fills card on Stripe's page, comes back | `payment_processor.checkout(mode: "subscription", ...)` — Stripe builds the page |
| **Embedded Elements** | `POST /account/subscription/embedded?plan=basic` | Card form renders **inside our app** via Stripe Elements `PaymentElement` | `Stripe::Subscription.create(payment_behavior: "default_incomplete")` — we get a `client_secret`, mount Elements ourselves |

Both flows produce real `Pay::Subscription` and `Pay::Charge` rows once Stripe's webhook fires.

The embedded flow needs the Stimulus controller [`stripe_elements_controller.js`](../../app/javascript/controllers/stripe_elements_controller.js): it lazy-loads `https://js.stripe.com/v3/`, mounts `PaymentElement` with the `client_secret`, and calls `stripe.confirmPayment({ confirmParams: { return_url } })` on submit.

**Both buttons must opt out of Turbo** with `form: { data: { turbo: false } }`. See §9.4.

---

## 7. Sync model: Stripe → Pay → users.plan

```
Stripe event ─→ /pay/webhooks/stripe (Pay::Webhooks::StripeController)
              ↓
        Pay::Webhook (raw event row, deleted after processing)
              ↓ (Pay::Webhooks::ProcessJob, Async)
   Pay::Subscription.create / .update  (Pay-managed)
              ↓ after_save_commit
        PlanSync#sync_user_plan   ← OUR concern
              ↓
        User.update_column(:plan, ...)
```

`PlanSync` (see [app/models/concerns/plan_sync.rb](../../app/models/concerns/plan_sync.rb)) runs on **every** `Pay::Subscription` save (any sub, any status), but it asks a different question: *"does this user have ANY active sub right now?"* It walks `pay_customers → pay_subscriptions` directly (not via the cached association — that bit us, see §9.13), filters for `status IN ('active','trialing')` and `ends_at IS NULL OR ends_at > now`, and writes the matching plan or `nil`.

Why "any active sub" rather than "this saved sub": if a user retries a failed Checkout, you end up with one active sub + several `incomplete` orphans. The naive "look at the saved sub" approach lets the last incomplete sub clobber a still-active one. See §9.12.

---

## 8. Operations: orphan subs, resync, flush

[lib/tasks/subscriptions.rake](../../lib/tasks/subscriptions.rake) ships two rake tasks:

```sh
bin/rails subscriptions:flush_orphans
# - Cancels every Pay::Subscription with status in (incomplete, incomplete_expired, canceled) in Stripe
# - Deletes the local Pay::Subscription rows
# - Recomputes users.plan for every user from any remaining active sub
# Use after broken Checkout attempts have piled up "ghost" incomplete subs.

bin/rails subscriptions:resync_from_stripe
# - For every Pay::Customer with a Stripe processor_id, lists all Stripe subscriptions
# - Upserts a local Pay::Subscription per remote sub
# Use when local DB drifted from Stripe (manual changes in dashboard, missed webhooks, fresh dev DB).
```

Typical recovery order: **flush_orphans → resync_from_stripe → reload dashboard**.

If you ever wipe the DB but keep the same Stripe account, just run `resync_from_stripe` to repopulate.

---

## 9. Troubleshooting — every error we hit, in order

Each entry: **symptom → root cause → fix**.

### 9.1 `Stripe::AuthenticationError: Invalid API Key provided`
**Symptom**: Every Stripe call dies on boot or first request.
**Cause**: Wrong env var name. Pay reads `STRIPE_PRIVATE_KEY`; older docs / dashboard label it `Secret key` / `STRIPE_SECRET_KEY`.
**Fix**: Rename in `.env` to `STRIPE_PRIVATE_KEY=sk_test_...` and `STRIPE_SIGNING_SECRET=whsec_...`. Restart server.

### 9.2 Tailwind v4: `@apply` produces invalid CSS, submit buttons render unstyled
**Symptom**: `bin/rails tailwindcss:build` fails with `Cannot apply unknown utility class 'btn'`, OR `<input type="submit" class="btn-primary">` renders as plain text.
**Cause**: Two separate Tailwind v4 quirks:
1. `@layer components { .btn { ... } .btn-primary { @apply btn ... } }` — v4 won't `@apply` another component-layer class. Promote `.btn` to `@utility btn { ... }`.
2. `@apply bg-[--color-brand]` compiles to `background-color: --color-brand` (no `var()` wrapper) → browser drops it → element has no background.
**Fix**: Use Tailwind v4 named utilities auto-generated from `@theme` tokens: `bg-brand`, `text-text`, `border-border`. See [app/assets/tailwind/application.css](../../app/assets/tailwind/application.css).

### 9.3 `f.submit` in Slim renders with no visible button
**Symptom**: Login/sign-up form has labels and inputs but no Submit button (or one with no background).
**Cause**: Tailwind v4 preflight resets `<input type=submit>` styling. With the broken `@apply bg-[--color-brand]` (§9.2) the button has no fill, so it visually disappears.
**Fix**: Either fix §9.2 OR replace `f.submit` with `button.btn-primary type="submit"` in Slim. We did both.

### 9.4 Cross-origin redirect to Stripe Checkout silently fails
**Symptom**: Server log shows `Redirected to https://checkout.stripe.com/...` and `Completed 302 Found`, but the browser stays on the form page. No error.
**Cause**: The form submitted as `TURBO_STREAM`. Turbo refuses to follow cross-origin redirects (security boundary). The 302 to `checkout.stripe.com` is dropped on the floor.
**Fix**: Opt the form out of Turbo:
```slim
button_to "Pay with hosted Checkout", account_subscription_path(plan: plan_key),
          method: :post, form: { data: { turbo: false } }
```
Same applies to the billing portal button (`POST /account/subscription/billing_portal`).

### 9.5 Embedded form POST returns 200 but page is blank
**Symptom**: `POST /account/subscription/embedded` returns 200 OK with rendered HTML in server log, but nothing changes in the browser.
**Cause**: Same Turbo issue as §9.4. The action does `render :embedded` (full HTML); Turbo expects a `turbo_stream` response from a POST and ignores the body.
**Fix**: Add `form: { data: { turbo: false } }` to the embedded button as well.

### 9.6 Slim multi-line attributes mangled when using `\` continuation
**Symptom**: A `<div>` you wrote with backslash line continuation renders without its `data-*` attributes; Stimulus controller never connects.
**Cause**: Slim does not treat `\` as attribute-list continuation. The trailing backslash and following lines become text inside the tag.
**Fix**: Use parentheses for multi-line attribute lists:
```slim
div(data-controller="stripe-elements"
    data-stripe-elements-publishable-key-value=ENV.fetch("STRIPE_PUBLIC_KEY", "")
    data-stripe-elements-client-secret-value=@client_secret
    data-stripe-elements-return-url-value="#{request.base_url}#{success_account_subscription_path}")
  form.space-y-4(data-stripe-elements-target="form")
    ...
```

### 9.7 `Invoice#payment_intent` raises `NoMethodError — BREAKING CHANGE`
**Symptom**: Embedded action crashes with Stripe's loud "BREAKING CHANGE" message about `Invoice#payment_intent` no longer being available.
**Cause**: Stripe API version Basil (2025-03-31) removed `Invoice#payment_intent` to support multiple partial payments on one invoice. Replacement is `Invoice#confirmation_secret` (shape `{ type: "payment_intent", client_secret: "..." }`).
**Fix**: In the embedded action:
```ruby
stripe_sub = Stripe::Subscription.create(
  customer: stripe_customer_id,
  items: [{ price: price_id }],
  payment_behavior: "default_incomplete",
  payment_settings: { save_default_payment_method: "on_subscription" },
  expand: ["latest_invoice.confirmation_secret"]
)
client_secret = stripe_sub.latest_invoice.confirmation_secret.client_secret
```
[my/subscriptions_controller#extract_client_secret](../../app/controllers/account/subscriptions_controller.rb) keeps a fallback chain (`confirmation_secret` → `invoice.payment_intent` → `invoice.payments[].payment.payment_intent`) so version skew is non-fatal.

### 9.8 `Pundit::NotDefinedError: unable to find policy Pay::Stripe::SubscriptionPolicy`
**Symptom**: After Pay persists a sub, `authorize @subscription` blows up looking for `Pay::Stripe::SubscriptionPolicy` (note the `Stripe::` segment).
**Cause**: `Pay::Subscription` uses STI. The actual instance class is `Pay::Stripe::Subscription`. Pundit derives policy name from the instance's class.
**Fix**: Pass the policy explicitly:
```ruby
authorize @subscription, policy_class: Pay::SubscriptionPolicy
authorize Pay::Subscription, :create?, policy_class: Pay::SubscriptionPolicy
```
Same applies to `Pay::Stripe::Charge` → `Pay::ChargePolicy`. See [Pay::SubscriptionPolicy](../../app/policies/pay/subscription_policy.rb) and [Pay::ChargePolicy](../../app/policies/pay/charge_policy.rb).

### 9.9 Singular resource: `embedded_account_subscriptions_path` (plural) is undefined
**Symptom**: `NoMethodError: undefined method 'embedded_account_subscriptions_path'`.
**Cause**: `resource :subscription` (singular) generates **singular** helpers for collection actions too: `embedded_account_subscription_path`, not the plural form. Don't be fooled by the `do ... collection do ... end ... end` block — singular vs. plural is decided by the outer `resource`/`resources` keyword.
**Fix**: Use the singular form everywhere: `success_account_subscription_path`, `cancel_account_subscription_path`, `embedded_account_subscription_path`, `billing_portal_account_subscription_path`.

### 9.10 Stripe redirects user to the wrong host (localhost → tunnel)
**Symptom**: Start on `localhost:3200`, complete hosted Checkout, get sent back to `https://machine.taile00403.ts.net/...`. Session may or may not carry across hosts; either way it's confusing UX.
**Cause**: Earlier code preferred an `APP_HOST` env var over `request.base_url`. Stripe's success_url / cancel_url / return_url are followed by the **user's browser**, not by Stripe's servers, so they don't need to be publicly reachable. `APP_HOST` solved a non-problem and created a new one.
**Fix**: Use `request.base_url` for all Stripe-bound URLs. Whichever host the user is on stays the host they come back to.
```ruby
def absolute_url(path)
  request.base_url.chomp("/") + path
end
```

### 9.11 `NoMethodError: undefined method 'checkout' for nil` (in subscriptions#create / #embedded)
**Symptom**: First subscription attempt for a brand-new user crashes on `current_user.payment_processor.checkout(...)`.
**Cause**: Pay 11 does NOT auto-create a `Pay::Customer` on first access to `payment_processor`. You have to call `set_payment_processor(:stripe)` once.
**Fix**: Add a `before_action`:
```ruby
before_action :ensure_payment_processor, only: %i[create embedded destroy billing_portal]

def ensure_payment_processor
  current_user.set_payment_processor(:stripe) if current_user.payment_processor.nil?
end
```
This is idempotent — `set_payment_processor` reuses an existing customer if one exists. The Stripe `cus_...` ID is filled in on the first Stripe API call (Checkout / Subscription.create), not here.

### 9.12 Subscription active in Stripe, but app says "No active plan"
**Symptom**: Stripe dashboard shows a paid Basic sub. App's dashboard badge says "No active plan". DB has the sub but `users.plan` is `nil`.
**Cause**: `PlanSync` was naively reading the *saved* sub's status. A user with one active sub + several `incomplete` orphans (from earlier failed retries) would have the latest incomplete sub's save trigger `PlanSync`, which derived plan from THAT sub (status: `incomplete` → `nil`) and wrote `users.plan = nil`, clobbering the correct value.
**Fix**: `PlanSync` now derives plan from *any* currently-active sub the user owns, not from the record being saved. See [plan_sync.rb#derived_plan_for](../../app/models/concerns/plan_sync.rb). Recovery: `bin/rails subscriptions:flush_orphans`.

### 9.13 `PlanSync` doesn't see freshly-created sub in tests
**Symptom**: Test creates `Pay::Subscription.create!(...)`, expects `user.reload.plan == "basic"`, gets `nil`.
**Cause**: Querying through `user.payment_processor.subscriptions` inside the `after_save_commit` callback returns a stale (cached) collection that doesn't include the just-saved record.
**Fix**: Query `Pay::Subscription` directly by `customer_id`:
```ruby
customer_ids = user.pay_customers.pluck(:id)
Pay::Subscription.where(customer_id: customer_ids, status: ACTIVE_STATUSES)...
```

### 9.14 `Pay::Subscription#active?` raises `NoMethodError: undefined method 'paused?'` in tests
**Symptom**: Direct-create tests fail inside the `PlanSync` callback when it calls `active?`.
**Cause**: Pay's `active?` delegates to `paused?` which is defined on the processor-specific subclass (`Pay::Stripe::Subscription`). When you `Pay::Subscription.create!(...)` in a test you get a bare instance without the processor adapter mixed in.
**Fix**: Check `status` directly:
```ruby
ACTIVE_STATUSES = %w[active trialing].freeze
def active_enough?
  ACTIVE_STATUSES.include?(status) && (ends_at.nil? || ends_at > Time.current)
end
```

### 9.15 `user.respond_to?(:pay_customer)` is false in Pay 11
**Symptom**: Test asserting `assert_respond_to user, :pay_customer` fails.
**Cause**: Pay 11 only exposes the class-level macro `pay_customer`. The instance methods are `payment_processor` (default customer) and `pay_customers` (collection).
**Fix**: Assert on the actual instance methods:
```ruby
assert_respond_to user, :payment_processor
assert_respond_to user, :pay_customers
```

### 9.16 Devise login with unconfirmed user shows no error
**Symptom**: Submit correct credentials before confirming email → page just reloads with no message.
**Cause 1**: `sessions/new.html.slim` didn't render the `_error_messages` partial.
**Cause 2**: The layout's flash reader only checked `notice` / `alert` keys, but Devise can use other flash keys.
**Fix**: Render `_error_messages` in the form AND replace the layout's two-line flash with a partial that iterates the full `flash` hash:
```slim
- flash.each do |key, message|
  - next if message.blank?
  - css = key.to_s == "notice" ? "flash-notice" : "flash-alert"
  p class=css role=(key.to_s == "notice" ? "status" : "alert") = message
```
See [app/views/shared/_flash.html.slim](../../app/views/shared/_flash.html.slim).

### 9.17 `Cannot render console from <tailscale IP>` warning
**Symptom**: Web-console's in-page exception inspector is missing when you visit through the tunnel.
**Cause**: `web-console` only renders for whitelisted IPs (default: 127.0.0.1, ::1). Tailscale IPs (100.64.0.0/10 CGNAT range) aren't on the list.
**Fix**: In `config/environments/development.rb`, open it up — `web-console` is dev-only, so there's no production risk:
```ruby
config.web_console.permissions = ["0.0.0.0/0", "::/0"] if defined?(WebConsole)
```

### 9.18 Tailscale tunnel hostname rejected by Rails
**Symptom**: Visiting via tunnel returns "Blocked hosts" error page.
**Cause**: Rails 8's `config.hosts` whitelists localhost only by default.
**Fix**: Add a regex for your tunnel:
```ruby
config.hosts << /.*\.taile00403\.ts\.net/   # use your own tailnet ID
```

### 9.19 First Stripe API call takes 2-4 seconds
**Symptom**: `POST /account/subscription` logs `Completed 302 Found in 3548ms (ActiveRecord: 80ms | Views: 0ms)`. The app feels slow.
**Cause**: Stripe API HTTPS round-trip latency. Not fixable from our side.
**Mitigations**:
- Show a loading spinner immediately on form submit.
- For embedded: optionally pre-create the subscription on `GET /account/subscription/new` (trades wasted Stripe subs for a snappier UX).
- For hosted: nothing to do — the user is redirecting away anyway.

### 9.20 Webhooks delivered twice
**Symptom**: Each Stripe event triggers two `POST /pay/webhooks/stripe` requests.
**Cause**: You're running BOTH `stripe listen` AND a Stripe Dashboard webhook endpoint pointing at the same URL. They both forward the same events.
**Fix**: Pick one (§5). For local dev: `stripe listen` only. Delete or disable the dashboard endpoint while developing locally.

### 9.21 Dev-mode log spam / sluggishness
**Symptom**: Even trivial requests log 50+ lines; pages feel laggy.
**Cause**: Default Rails 8 dev config turns on a lot of debugging niceties that compound: `verbose_query_logs`, `query_log_tags_enabled`, `verbose_enqueue_logs`, `verbose_redirect_logs`, `annotate_rendered_view_with_filenames`, and Bullet's `add_footer` + `console` + `bullet_logger`.
**Fix**: Flip the noisiest off (see [config/environments/development.rb](../../config/environments/development.rb)). Keep `Bullet.rails_logger = true` so N+1s still land in `log/development.log`.

### 9.22 Pay STI scoping makes `current_subscription` invisible in tests
**Symptom**: Test creates `Pay::Subscription.create!(customer: pay_customer, ...)` for a `Pay::Stripe::Customer`, then `pay_customer.subscription` (or `Billing#current_subscription`) returns `nil` even though the row exists in the DB.
**Cause**: `Pay::Stripe::Customer#subscriptions` is declared with `class_name: "Pay::Stripe::Subscription"`, so the association only sees rows whose `type` column matches the STI subclass. A bare `Pay::Subscription` row is invisible to the customer association. Pre-existing tests that query `Pay::Subscription.where(customer_id: ...)` directly (e.g. `plan_sync_test.rb`) get away with it — anything that touches the customer-side association breaks.
**Fix**: Create through the STI subclass in tests:
```ruby
Pay::Stripe::Subscription.create!(
  customer: pay_customer,
  processor_id: "sub_test",
  name: "default",
  processor_plan: ENV["PAY_STRIPE_PLAN_BASIC"],
  status: "active"
)
```
The shared `setup_billing(user, plan:, processor_id:)` helper in `test/support/billing_fixtures.rb` does this correctly — use it instead of hand-rolling the boilerplate.

### 9.23 `Pay::Subscription#cancel` WebMock stub raises `TypeError: can't convert NilClass into an exact number`
**Symptom**: Test calls `subscription.cancel` against a WebMock stub of `POST /v1/subscriptions/sub_xxx`, deep stack trace ends in `Time.at(nil)`.
**Cause**: Pay's `cancel` is a **POST**, not a DELETE — it sets `cancel_at_period_end: true`. Pay then reads `@api_record.cancel_at` from the Stripe response and feeds it to `Time.at(...)` to compute the local `ends_at` timestamp. If `cancel_at` is missing or nil, `Time.at(nil)` raises `TypeError` from inside Pay (not from your test).
**Fix**: The cancel stub must return `cancel_at` as a Unix timestamp:
```ruby
stub_request(:post, "https://api.stripe.com/v1/subscriptions/#{processor_id}")
  .with(body: hash_including("cancel_at_period_end" => "true"))
  .to_return(
    status: 200,
    headers: { "Content-Type" => "application/json" },
    body: {
      id: processor_id,
      object: "subscription",
      status: "active",
      cancel_at_period_end: true,
      cancel_at: Time.now.to_i + 30 * 24 * 3600
    }.to_json
  )
```
The canonical helper lives in `test/support/stripe_stubs.rb` as `stub_stripe_subscription_cancel(id:)`; reach for it before rolling your own.

### 9.24 SimpleCov reports near-zero coverage for code that is clearly tested
**Symptom**: `bin/rails test` runs the full suite green, but `coverage/index.html` shows obviously-tested concerns (Billing, PlanSync) at 0% line coverage. Headline number is wildly under-reporting.
**Cause**: `bin/rails test` (no path arg) runs the `test:prepare` rake task **before** loading `test_helper.rb`. `test:prepare` boots Rails, which runs every `to_prepare` initializer and loads the Billing concern, PlanSync, etc. If `SimpleCov.start` is called inside `test_helper.rb`, those files are already loaded *without* `Coverage` probes — workers inherit probe-less bytecode and record nothing.
A secondary trap: trying to "fix" this with `SimpleCov.at_fork.call(worker)` in `parallelize_setup` makes it **worse**. `at_fork` re-runs `SimpleCov.start` in the child, which detaches the parent's inherited probes from any file already in memory — so the file goes from "tracked but inherited" to "untracked at all".
**Fix**: Start SimpleCov in `config/boot.rb` (the very first Ruby file Bundler runs, before Rails). The actual configuration lives in [config/simplecov_setup.rb](../../config/simplecov_setup.rb). In `test_helper.rb`, `parallelize_setup` only renames the per-worker resultset (`SimpleCov.command_name "Worker-#{worker}"`) and does NOT call `at_fork`; the parent's empty resultset is suppressed via `SimpleCov.external_at_exit = true`. With this layout the headline number is honest and parallel testing keeps working.

---

## 10. Production checklist (Kamal)

Before `kamal deploy`:

- [ ] `STRIPE_PUBLIC_KEY`, `STRIPE_PRIVATE_KEY`, `STRIPE_SIGNING_SECRET`, `PAY_STRIPE_PLAN_BASIC`, `PAY_STRIPE_PLAN_PRO`, `SECRET_KEY_BASE` all set in `.kamal/secrets` (or whatever env source you wire into the container).
- [ ] **Live-mode** Stripe products + prices created. Production price IDs are different from test; use a separate `PAY_STRIPE_PLAN_*` per env.
- [ ] Stripe Dashboard webhook endpoint registered against the deployed URL with the event list from §5. Use its signing secret (NOT the CLI one) for `STRIPE_SIGNING_SECRET` in production.
- [ ] Stripe Customer Portal **enabled in live mode** (separate toggle from test mode).
- [ ] `config.hosts` includes your real domain.
- [ ] Pay's `support_email` and `business_name` in [config/initializers/pay.rb](../../config/initializers/pay.rb) updated from the placeholder.
- [ ] Devise mailer `default_url_options[:host]` set to your real domain in `config/environments/production.rb`.
- [ ] `Rails.application.credentials.secret_key_base` (or `SECRET_KEY_BASE` env) set.
- [ ] After first deploy, run `bin/rails subscriptions:resync_from_stripe` once to ensure your live DB and Stripe agree.

---

**Last updated**: see `git log -- docs/stripe_integration/`. Add new failures + fixes to §9 as you encounter them; future-you and the next dev will thank you.
