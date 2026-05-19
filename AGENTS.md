# stripe-pdf-generation-demo

This file provides guidance for AI coding agents working in this repository.

## What is this app?

A demo Rails app for a client showing four capabilities:

1. Two-tier Stripe subscription billing (via the Pay gem)
2. PDF generation from subscription data (via HexaPDF)
3. Minimal admin panel (via ActiveAdmin, mounted at `/admin`)
4. Internationalisation — English + French, switched via a header toggle; every user-facing string lives in `config/locales/`

Everything is behind Devise authentication (end-users) or a separate AdminUser Devise scope (admin). No public pages. No extra features.
Keep it small, keep it obvious.

## Stack

- Ruby on Rails 8.1.x, PostgreSQL
- Devise (auth — `User` and `AdminUser` scopes), Pundit (authorization), Pay + Stripe (billing)
- HexaPDF (PDF generation — pure Ruby, no binary deps)
- ActiveAdmin 3.5 (admin panel at `/admin`; Sprockets-served for AA assets, Propshaft + importmap for the rest)
- Hotwire (Turbo + Stimulus), Tailwind CSS
- Slim templates (not ERB)
- I18n (Rails default) — every UI string is in `config/locales/en.yml`
- Kamal (deployment), dotenv (local secrets)
- Rubocop, Brakeman, Bullet, Rubycritic (dev tooling)

## Development Commands

```sh
bin/setup          # install gems, create and migrate DB
bin/dev            # start dev server (Foreman: Rails + Tailwind watcher)
bin/rails console  # Rails console
```

Local URL: `http://localhost:3000`

## Testing

```sh
bin/rails test                          # run all tests
bin/rails test test/path/file_test.rb   # single file
```

No system tests for this demo. Unit and controller tests only.

## Security Scan

```sh
bundle exec brakeman --no-pager
bundle exec rubocop
bundle exec bundler-audit check --update
bin/importmap audit
bin/ci   # runs all four in one shot
```

## Pre-commit hook

`bin/setup` runs `git config core.hooksPath .githooks` so `.githooks/pre-commit` is active for every developer. The hook runs the same four checks GitHub Actions runs — rubocop, brakeman, bundler-audit, importmap audit — and aborts the commit on any failure. `git commit --no-verify` is the documented escape hatch and must be justified.

## Deploy

```sh
kamal deploy        # deploy to production via Kamal
kamal app logs      # tail production logs
```

Secrets live in `.env` (never committed). Kamal reads from `.kamal-env`.

## Architecture

###

Use DRY and Divide and Rule strategy, Use 37 Signals, Basecamp Rails architecture styles
Move code to Model and Controller concerns keep models fat and controllers slim.

### Auth

Devise handles all authentication. Every controller inherits `before_action :authenticate_user!`
from ApplicationController. No unauthenticated routes exist.

Pundit handles authorization. Policies live in `app/policies/`.
Call `authorize` in every controller action. No skipping.

**Policy hierarchy** (DRY OOP base):

```text
ApplicationPolicy         # Pundit default — every action returns false (deny-by-default)
  └── AuthenticatedPolicy # every action returns signed_in? — base for app-owned resources
        ├── HomePolicy
        └── Pay::SubscriptionPolicy
              └── (overrides destroy? -> owned?)
        └── Pay::ChargePolicy
              └── (overrides show? -> owned? when record is an instance)
```

`ApplicationPolicy` exposes two protected predicates that every subclass can call:

- `signed_in?` — `user.present?`
- `owned?` — walks `record.customer.owner` (Pay records) or `record.user` (bare AR), returns `true` only when the resolved owner equals `user`. Returns `false` for class-shaped records (e.g. `authorize Pay::Subscription, :create?`) so subclasses can mix class-mode and instance-mode safely.

When the actual instance is an STI subclass Pundit can't resolve (e.g. `Pay::Stripe::Subscription` → `Pay::Stripe::SubscriptionPolicy` doesn't exist), pass the base class explicitly:

```ruby
authorize @subscription,            policy_class: Pay::SubscriptionPolicy
authorize Pay::Subscription, :new?, policy_class: Pay::SubscriptionPolicy
```

Rule of thumb for new policies: subclass `AuthenticatedPolicy`, override only the actions that need ownership (or any deny-by-default), and lean on `owned?` rather than rewriting the customer→owner walk in each policy.

### Subscriptions

Pay gem wraps Stripe. Two plans: Basic and Pro.
Billing portal handled via Pay's built-in routes.

**Stripe-touching logic lives in a `Billing` concern on `Pay::Customer`**, mixed in via `config/initializers/pay_customer_billing.rb`. The concern exposes:

- `start_hosted_checkout(price_id:, success_url:, cancel_url:)` — Stripe-hosted Checkout
- `start_embedded_subscription(price_id:)` — `default_incomplete` sub + `client_secret` extraction (handles API version drift: Basil `confirmation_secret` → older `payment_intent` → multi-payment `payments.data[0]` fallback chain)
- `open_billing_portal(return_url:)` — billing portal session
- `current_subscription` / `active_subscription` — query helpers preferring an active sub over orphans

Why a concern on `Pay::Customer` instead of a service object: AGENTS.md bans service objects; behaviour belongs on the model. Pay is extended in initializer because the class lives in the gem. **Include in both `Pay::Customer` AND `Pay::Stripe::Customer`** — STI autoload order in Pay can otherwise leave the subclass without the method at first call.

Controllers stay slim: `current_user.payment_processor.start_hosted_checkout(...)` and handle the redirect/flash. No Stripe SDK imports in controllers.

`Account::SubscriptionsController` (see [app/controllers/account/subscriptions_controller.rb](app/controllers/account/subscriptions_controller.rb)) is the pattern — auth, authorize, dispatch to `billing`, render/redirect with friendly flashes. The two redirect helpers (`missing_plan_redirect`, `stripe_failure_redirect`) collapse the duplicate error paths.

### PDF Generation

HexaPDF generates PDFs on the fly. No stored files for this demo. Controllers stream the result directly with `send_data`.

**Class hierarchy** (`app/pdfs/`):

```text
Pdf                       # base — Canvas plumbing + drawing primitives
 └── InvoicePdf           # layout only — calls primitives, never touches Canvas
 └── <future docs here>
```

The base class exposes three tiers of primitives so subclasses stay declarative:

| Tier | Methods | Use when |
| --- | --- | --- |
| Low-level | `text`, `rule`, `money` | Custom one-off layout |
| Mid-level | `heading`, `meta_lines`, `two_columns`, `table`, `total_row`, `footer_lines` | Standard business-document blocks |
| Structural | `render`, `filename`, `draw` | Subclass only overrides `draw` (required) and `filename` (defaults to `class_name.pdf`) |

New PDF type: subclass `Pdf`, implement `#draw` calling the helpers above, override `#filename`. No HexaPDF or StringIO knowledge required at the subclass level.

Do not use background jobs for PDF generation in this demo — it is synchronous and instant.

### Admin panel (ActiveAdmin)

ActiveAdmin 3.5 is mounted at `/admin`. The admin is a **separate Devise scope** (`AdminUser`) — it does NOT share a sessions table with end-user `User` records, and its controllers descend from `ActiveAdmin::BaseController`, not `ApplicationController`, so the end-user `before_action :authenticate_user!` and `rescue_from Pundit::NotAuthorizedError` don't leak in. Pundit is for the customer-facing app only; the admin panel uses its own Devise-backed auth.

**File layout** (`app/admin/`):

```text
app/admin/
  dashboard.rb           # three summary panels (Users, Active subscriptions, Charges this month)
  users.rb               # End-user index/show -- read-only (no permit_params)
  pay_customers.rb       # Pay::Customer index/show -- read-only
  pay_subscriptions.rb   # Pay::Subscription index/show -- read-only
  pay_charges.rb         # Pay::Charge index/show -- read-only
  admin_users.rb         # AdminUser CRUD (full — admins manage admins)
```

Rules:

- **Read-only by default.** Business-domain registrations (`User`, `Pay::*`) declare `actions :index, :show` and omit `permit_params`. Mutating production data through the admin is out of scope for the demo. The only mutable resource is `AdminUser` itself.
- **No business logic in `app/admin/*.rb`.** Same rule as controllers: behaviour goes on the model. AA files are configuration — column lists, filters, dashboard widgets.
- **No new policies for the admin namespace.** Pundit is for the end-user `Account::` controllers. Don't try to authorize ActiveAdmin actions through Pundit; AA's own `current_admin_user` is the boundary.
- **AdminUser Devise modules**: `:database_authenticatable, :recoverable, :rememberable, :validatable, :trackable, :lockable, :timeoutable`. Stricter than end-user `User` on purpose — admin login is brute-forceable on the public internet, so lockout + idle-timeout matter. Defaults are Devise's (`maximum_attempts = 20`, `timeout_in = 30.minutes`, unlock via email or wait). Tune in `config/initializers/devise.rb` if you need tighter.
- **AA admin comments are disabled.** `config.comments = false` in `config/initializers/active_admin.rb`. The `active_admin_comments` table has been dropped. Don't re-enable without a use case — orphan UI surface is a security liability, not a feature.
- **AA DSL strings live in i18n.** Panel titles, menu labels, paragraph copy in `app/admin/*.rb` go through `I18n.t("active_admin.*")` — the same "I18n by default" rule the rest of the app follows. Column overrides (`column("Amount")`) translate at file-load time; menu labels use `proc { I18n.t(...) }` so they're re-evaluated per request (future-proofs per-request locale).
- **SimpleCov filters** `app/admin/` and `app/models/admin_user.rb` — they are AA DSL / Devise boilerplate, not unit-testable logic. The 90% coverage gate excludes them; don't add ceremonial tests just to bump the number.
- **Asset stack** — Propshaft is the only pipeline. AA still ships its CSS as SCSS, which Propshaft cannot process, so [lib/tasks/active_admin.rake](lib/tasks/active_admin.rake) compiles `app/assets/stylesheets/active_admin.scss` → `app/assets/builds/active_admin.css` via the bundled `sassc` gem. `bin/setup` runs it once and the task is `enhance`d onto `assets:precompile` for production. The build output sits in the same `app/assets/builds/` folder as Tailwind's compiled CSS.
- **CSS isolation between admin and customer app** — Propshaft's `stylesheet_link_tag :app` shortcut auto-includes every `.css` file under `app/assets/**`, which would drag the unscoped `active_admin.css` (normalize.css, `body{...}`, `h1{...}`) into the customer layout and clobber the Tailwind look. The customer layout therefore lists stylesheets explicitly: `stylesheet_link_tag "application", "tailwind"`. AA's own layout loads `active_admin.css` separately on `/admin/*` pages. The two design systems never share a page.
- **Ransack 4 allowlists** — every AA-registered model must declare `ransackable_attributes` / `ransackable_associations`. `User` and `AdminUser` declare them inline; `Pay::Customer` / `Pay::Subscription` / `Pay::Charge` are vendored, so they get re-opened in [config/initializers/pay_ransackable.rb](config/initializers/pay_ransackable.rb). Auth secrets (`encrypted_password`, `*_token`, `*_ip`) and raw Stripe JSONB blobs (`data`, `metadata`, `object`) are deliberately excluded — they MUST NOT be filterable/sortable through admin URLs.
- **AA controller inheritance gotcha** — `ActiveAdmin::BaseController` ultimately descends from our `ApplicationController` (via `InheritedResources::Base`). That means it inherits `before_action :authenticate_user!` (the customer User scope), which would bounce admins to `/users/sign_in` instead of letting AA's own `authenticate_admin_user!` run. The fix is a `to_prepare` block at the bottom of [config/initializers/active_admin.rb](config/initializers/active_admin.rb) that calls `skip_before_action :authenticate_user!` on the AA chain. The `LocaleSwitching` concern survives the inheritance and gives the admin namespace the same `session[:locale]` toggle as the customer side.
- **AA menu IDs vs labels** — `menu parent:` and `menu id:` are looked up as String/Symbol IDs (see `ActiveAdmin::Menu#normalize_id`). `menu label:` and `content title:` accept procs and resolve at render time. Mixing them up (passing a proc to `parent:`) raises `TypeError (Proc isn't supported as Menu ID)`. The "Admin" parent group is pre-registered with a stable ID and a proc label in `config.namespace :admin do |admin|; admin.build_menu :default do ... end; end` inside the AA initializer.

Local admin credentials (seeded in development only): `admin@example.test` / `password`.

### Internationalisation (I18n) — ENFORCED BY DEFAULT

**This is a hard rule, not a guideline.** Every user-facing string in this app goes through `t()`. The app ships a single locale (`en`) today; a second locale must be a YAML-only change. If your diff adds an English word to a `.slim` file, `.rb` controller, helper, mailer, or PDF, the diff is incomplete.

**Locale files (the only places English copy is allowed to live):**

| File | What lives there |
| --- | --- |
| `config/locales/en.yml` | App-owned strings — `app.*`, `nav.*`, `flash.*`, `plans.*`, `home.*`, `account.*`, `pdf.*` |
| `config/locales/devise.en.yml` | Devise's upstream catalogue + our extended view-side keys under `devise.<controller>.<action>.*` and `devise.mailer.<action>.*` |

Setup is in `config/application.rb` and must not be downgraded:

```ruby
config.i18n.default_locale     = :en
config.i18n.available_locales  = [:en, :fr]
config.i18n.fallbacks          = true
```

`fallbacks = true` means a French page with a missing key shows the English value instead of raising `I18n::MissingTranslation`. Leave it on. When you add a new key, add it to **both** `en.yml` and `fr.yml` — the parallel mirror is the rule, fallbacks are a safety net, not a substitute.

**Switching locale (runtime).**

- `ApplicationController` runs `around_action :switch_locale`. The action reads `session[:locale]`, validates it against `I18n.available_locales`, and wraps the request in `I18n.with_locale(...)`. `around_action` is the idiomatic Rails 7+ pattern — locale is reset even when the action raises, so it never leaks across requests.
- `LocalesController#update` is the toggle endpoint. Route: `PATCH /locale` (singular `resource :locale, only: :update`, no namespace). Pundit authorize is `authorize :locale` → `LocalePolicy#update?` → inherits `signed_in?` from `AuthenticatedPolicy`. The controller writes `params[:locale]` to `session[:locale]` (only if the symbol is in `available_locales`) and `redirect_back`.
- The header includes a `button_to` toggle that posts to `locale_path(locale: <other_locale>)`. The toggle is rendered only inside the `if user_signed_in?` block — signed-out flows render in `I18n.default_locale`.
- `<html lang=I18n.locale>` on the layout keeps screen readers and the browser in sync with the active locale.
- **Admin namespace is NOT locale-aware.** ActiveAdmin controllers descend from `ActiveAdmin::BaseController`, not `ApplicationController`, so the `switch_locale` around-action does not run for `/admin/*`. The admin panel always renders in `I18n.default_locale = :en`. If a future requirement asks for per-admin locale, add a parallel `around_action` to an AA base controller — do not try to share `session[:locale]` across the two Devise scopes.

**Mandatory conventions:**

1. **Lazy lookups inside views and controllers.** `t(".title")` inside `app/views/account/subscriptions/new.html.slim` resolves to `account.subscriptions.new.title`. Same in `Account::SubscriptionsController#create` → `account.subscriptions.create.plan_updated`. The YAML tree mirrors the controller/view path 1:1.
2. **Fully-qualified lookups elsewhere.** Helpers (`app/helpers/`), PDFs (`app/pdfs/`), mailers, models, rake tasks — anywhere outside the view/controller scope uses the full key: `I18n.t("pdf.invoice.heading")`, `I18n.t("plans.names.basic")`.
3. **Interpolation uses `%{var}`** and is passed as keyword args: `t(".pay_cta", price: plan_price_label(@plan))`.
4. **HTML-safe strings end with `_html`.** Any locale value containing `'`, `"`, `&`, or intentional inline HTML lives under a key ending in `_html`, and the lookup key in the template must match. Rails auto-marks `_html`-suffixed values as `html_safe`. Slim would otherwise turn `don't` into `don&#39;t`, and tests asserting against the rendered body will fail.
5. **`f.label :email` and friends resolve through ActiveRecord.** Bare `f.label :email` pulls `activerecord.attributes.user.email`. Don't replace those with `t(".email")` unless the upstream attribute label isn't what you want.
6. **Devise's own UI** is translated via `config/locales/devise.en.yml`. The upstream gem catalogue is already in there; our view-side additions (titles, submit buttons, links) extend the same tree. Do **not** duplicate Devise keys in `config/locales/en.yml`.
7. **ActiveAdmin's chrome** (sidebar, breadcrumbs, pagination, default buttons) ships translated under `active_admin.*` by the gem. **Our** AA DSL files in `app/admin/*.rb` extend the same `active_admin.*` namespace in `config/locales/en.yml` — panel titles, menu labels, custom column overrides, paragraph copy all go through `I18n.t("active_admin.menus.*")`, `I18n.t("active_admin.dashboard_panels.*")`, etc. Domain resources registered in `app/admin/` also derive column labels from `human_attribute_name`; if a default AR-derived column label is wrong, add the override under `activerecord.attributes.<model>.<column>` in the locale file, not as a literal in the AA DSL.
8. **Tests assert against rendered English**, not against locale keys. The English text in YAML is the source of truth; align test expectations to it. Never change a translation just to make a test pass — change the test if the wording was wrong, otherwise leave both alone.

**Forbidden patterns (these are bugs — reject them in review):**

```slim
/ ❌ Hardcoded English in a Slim template
h1.h-page Welcome
button.btn-primary Sign in
p.muted Pick a tier to continue.

/ ✅ Translated lookups
h1.h-page = t(".welcome")
button.btn-primary = t(".sign_in")
p.muted = t(".pick_a_tier")
```

```ruby
# ❌ Hardcoded English in a controller flash
redirect_to root_path, alert: "You are not authorized."

# ❌ Hardcoded English in a PDF
text("Invoice", at: [50, 780])

# ✅ Translated
redirect_to root_path, alert: t("flash.not_authorized")
text(I18n.t("pdf.invoice.heading"), at: [50, 780])
```

**Locale tree (top-level groupings in `en.yml`):**

- `app.*` — global product strings (title, name)
- `nav.*` — header navigation labels
- `flash.*` — controller-agnostic flash messages (Pundit denial, generic errors)
- `plans.*` — plan names, summaries, price suffixes
- `home.show.*`, `account.subscriptions.<action>.*`, `account.invoices.<action>.*` — page-scoped strings, keyed to controller#action
- `pdf.invoice.*` — PDF copy

**Adding a new page or action:**

1. Add the new key(s) to the matching subtree in `config/locales/en.yml` (or `devise.en.yml` if it's a Devise extension).
2. Reference them with `t(".key")` (lazy) inside the new view/controller.
3. For helpers/PDFs/mailers, use the fully-qualified key.
4. If the value contains an apostrophe or HTML, suffix the key with `_html`.
5. Add a controller test that asserts the rendered English appears in the response body or flash. (This is the safety net that catches drift between YAML and code.)

**Rule of thumb:** if you type an English word anywhere that is not a `.yml` file, you are wrong. Stop, add the key, use `t()`.

### Models

Business logic goes in DRY models, use concerns, services and OOP. Service objects are not used.
If a method wraps one line with no explanation, inline it.
If a concern is used by only one model, inline it into the model.

### Controllers

Thin DRY controllers, use concerns, services and OOP. No logic beyond: authenticate, authorize, find record, respond.
Use standard CRUD actions. If you need a non-CRUD action, make it a new resource.

`Account::` namespace for anything scoped to `Current.user` (e.g., `Account::SubscriptionsController`).
**Flash strings and rescue messages go through `t(...)`** — see the I18n section. A controller emitting a literal `alert: "Something failed"` is a bug.

### Views

Slim, not ERB. Use DRY helper methods to keep view clean and lean. All templates in `app/views/`.
Helpers take explicit arguments — no magical ivars inside helpers.
If a partial has no HTML (just Ruby), it belongs in a helper or model method.
**Every string in a view goes through `t(...)`** — see the I18n section above. A `.slim` file with an English literal is a bug.

Turbo Streams use canonical style:

```ruby
turbo_stream.update [@subscription, :status], partial: "subscriptions/status", locals: { subscription: @subscription }
```

### Stimulus

Use `data-*-target` attributes. Never query CSS selectors from controllers.
Keep controllers small. DOM manipulation only — no business logic.

### Styling — consolidated Tailwind

Tailwind v4 is the styling layer. All custom design tokens and reusable component classes live in **one file**: `app/assets/tailwind/application.css`. Views consume those classes; they do not invent their own.

Structure of `tailwind/application.css`:

1. `@import "tailwindcss"` at the top.
2. `@theme { … }` block for **design tokens** — brand colour, notice/alert pair, surface, border, text, and any muted variants. New colours are added here, not in `bg-[#hex]` literals inside views.
3. `@layer components { … }` block for **shared component classes** — page chrome (`.page`, `.h-page`, `.card`), form primitives (`.form`, `.form-field`, `.form-label`, `.form-input`, `.form-hint`, `.form-errors`), buttons (`.btn-primary`, `.btn-secondary`, `.btn-danger`, `.btn-link`), and flash (`.flash-notice`, `.flash-alert`).

Rules:

- **Reach for a shared class first.** Use raw Tailwind utilities in a view only when nothing in `application.css` fits — and when that happens twice for the same pattern, promote it to a class in `application.css`.
- **No utility soup in views.** Long `class="px-4 py-2 rounded-md bg-indigo-600 …"` strings in templates are a sign the class belongs in `@layer components`.
- **Tokens, not hex codes.** When a new colour is needed, add it to `@theme` and reference it via `[--color-name]`. Never paste a hex literal into a view or into another component class.
- **Component classes compose with `@apply`.** `.btn-primary { @apply btn bg-[--color-brand] … }` is the pattern. Stay declarative — no nested selectors, no `:hover` rules outside `@apply`.

The goal is one place to retune the look-and-feel and one place to audit when the design changes.

## Coding Philosophy (37signals style)

**I18n by default.** Every user-facing string in views, controllers, helpers, mailers, and PDFs goes through `t(...)`. Hardcoded English is a bug. See the I18n section above for the full rules; the short version is: if you type an English word outside of a `.yml` file, you are wrong.

**Abstractions must earn their keep.**
If you can't name 3+ cases that need an abstraction, inline it.

**Compute at write time, not read time.**
Store derived values on save. Don't compute in views or serializers.

**Validation cascade — push integrity as far down the stack as it will go.**
Each layer is the last line of defense; never skip a level just because the one above it already covers the case. In order:

1. **Database.** Indexes, `unique: true`, `null: false`, foreign keys, `check` constraints. These are the only guarantees that survive concurrent writes, bypassed callbacks, raw SQL, and rake tasks. Add them in migrations on the same commit as the column they protect.
2. **Model.** AR validations (`validates :email, presence:, uniqueness:`), `belongs_to` required-by-default, `enum`, `before_validation` normalisation. These give Rails form errors and stop bad records before SQL is even attempted, but they do not bind on concurrent writes — the DB constraint above is what catches the race.
3. **Controller.** Strong parameters (`params.require(:user).permit(...)`), Pundit `authorize`, `before_action` guards, rate limits. These shape what the user is allowed to send in the first place.
4. **View.** HTML form attributes (`required`, `type="email"`, `pattern=`, `maxlength=`), Stimulus / Turbo client-side checks. UX polish only — never the only enforcement; the layers below must still pass.

A validation that lives at exactly one layer is a bug waiting to happen. Email uniqueness, for example, needs a unique DB index *and* a model `validates :email, uniqueness: true` (so the user gets a form error, not a 500 from the unique constraint violation).

**Positive names.**
`active` not `not_deleted`. `visible` not `not_hidden`.

**Explicit over clever.**
`case` statements beat `method_missing` for 2–3 variations.
Define methods explicitly rather than using metaprogramming.

**Use Rails idioms.**

- `after_save_commit` not `after_commit on: %i[create update]`
- `pluck(:email)` not `map(&:email)` when querying
- `head :no_content` for PATCH/DELETE that have no body
- `touch: true` on associations for cache invalidation
- `StringInquirer` for predicate methods: `status.active?`

**Tests should not shape design.**
Never add code or expose methods solely to make testing easier.
Use fixtures, not factories. Mock at the boundary, not inside models.

**No `respond_to` block when templates exist for both formats.**
Rails infers format from templates automatically.

## Testing architecture

Minitest, fixtures, no system tests. The suite mirrors `app/` 1:1:

```text
test/
  controllers/   # mirrors app/controllers/, including Account:: namespace
  models/        # AR models + concerns/
  policies/      # mirrors app/policies/, including pay/ subdir
  pdfs/          # mirrors app/pdfs/
  views/         # ActionView::TestCase smoke tests for Slim templates
  support/       # shared helpers, auto-required by test_helper.rb
  fixtures/      # YAML fixtures — the only data source
```

WebMock is wired in `test_helper.rb` with `disable_net_connect!(allow_localhost: true)`. SimpleCov starts in **`config/boot.rb`** (before Rails — `bin/rails test` runs `test:prepare` which boots the app *before* `test_helper.rb` is loaded, so the SimpleCov hook has to fire even earlier). Per-worker resultsets are merged via `parallelize_setup`/`parallelize_teardown` and the parent process is suppressed with `SimpleCov.external_at_exit = true` so it can't clobber the merge. `dotenv-rails` loads `.env` in the `test` env too, so `test_helper.rb` sets `Stripe.api_key` and `PAY_STRIPE_PLAN_*` with `||=` — tests work with or without a developer's `.env`.

The 5 rules, in priority order:

1. **Fixtures, not factory_bot.** The "Tests should not shape design" rule above applies: no factories, no `build_stubbed`, no DSLs that exist purely to make tests easier to write. Fixtures in `test/fixtures/` are the only data source. The only allowed dynamic builders are the `test/support/` helpers (currently `setup_billing(user, plan:, processor_id:)`), which exist to DRY up genuine Pay STI boilerplate — not to replace fixtures.
2. **Mock at the boundary (WebMock), never deeper.** Stub Stripe at the HTTP layer via the helpers in `test/support/stripe_stubs.rb`. Never stub `Stripe::Customer.create` or any other SDK method directly. The real Stripe Ruby SDK runs against the WebMock stub, which is what catches SDK-version drift (see §9.7 in the Stripe runbook for an example of why this matters).
3. **One shared helper file per concern in `test/support/`.** Today that is `stripe_stubs.rb` (Stripe REST stubs) and `billing_fixtures.rb` (Pay STI plumbing). Add to these rather than creating new files when a stub or helper is missing. If something is used only in one test, inline it there.
4. **Plain `assert` / `refute` for everything, including policies.** No shoulda-matchers, no `pundit-matchers`. Test policies as `Policy.new(user, record).action?` and assert on the boolean. Cover both class-shaped (`authorize Pay::Subscription, :create?`) and instance-shaped (`authorize @sub`) calls.
5. **Coverage gate: SimpleCov line coverage, 90% minimum.** `bin/rails test` regenerates `coverage/index.html` on every run. The `coverage/` folder is gitignored in full — it is regenerated, never checked in.

**Common pitfalls** (full entries live in the Stripe runbook, [docs/stripe_integration/README.md](docs/stripe_integration/README.md) §9):

- **Pay STI scoping in tests.** Create subs as `Pay::Stripe::Subscription`, not `Pay::Subscription` — `Pay::Stripe::Customer#subscriptions` is scoped to the STI subclass, so a bare `Pay::Subscription` row is invisible to the customer association (and therefore to `current_subscription`).
- **`Pay::Subscription#cancel` is a POST, not a DELETE, and needs `cancel_at` in the response.** WebMock stubs for cancel must return `cancel_at` (Pay calls `Time.at(cancel_at)` to set `ends_at` — `Time.at(nil)` raises `TypeError`).
- **SimpleCov + Rails 8 parallel testing.** `bin/rails test` runs `test:prepare` which boots Rails *before* `test_helper.rb` loads, so `SimpleCov.start` has to live in `config/boot.rb`. `SimpleCov.at_fork` is **harmful** here — calling it in each worker re-runs `SimpleCov.start` and detaches the inherited Coverage probes from already-loaded files (Billing, PlanSync). The canonical setup lives in `config/boot.rb` + `config/simplecov_setup.rb` + the empty `parallelize_setup` rename in `test_helper.rb` — read those when in doubt rather than reinventing.

## What this app is NOT

- Not a multi-tenant app
- Not a background job app
- Not an API

If asked to add any of the above: decline, or raise it first. This is a demo.

The admin panel (ActiveAdmin) is intentionally minimal — read-only on every business resource. It is **not** a CRUD admin for editing customer data, and it should not grow into one. Adding `permit_params` to a `Pay::*` registration to "let an admin fix a stuck subscription" is a Stripe-side problem; fix it in Stripe, not in our DB.

## Environment Variables

Managed via `.env` in development. Never commit secrets. Never hardcode them.

Required keys (see `.env.example`):

```text
STRIPE_PUBLIC_KEY
STRIPE_PRIVATE_KEY       # "Secret key" in the Stripe dashboard
STRIPE_SIGNING_SECRET    # Webhook endpoint "signing secret" in the dashboard
PAY_STRIPE_PLAN_BASIC
PAY_STRIPE_PLAN_PRO
SECRET_KEY_BASE
```

`DATABASE_URL` is optional in development -- `config/database.yml` defaults to the local Postgres socket with the OS user. Set `DATABASE_URL` only to override (e.g. point at a remote DB).
