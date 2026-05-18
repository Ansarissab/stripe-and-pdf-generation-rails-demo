# stripe-pdf-generation-demo

This file provides guidance for AI coding agents working in this repository.

## What is this app?

A demo Rails app for a client showing two capabilities:

1. Two-tier Stripe subscription billing (via the Pay gem)
2. PDF generation from subscription data (via HexaPDF)

Everything is behind Devise authentication. No public pages. No extra features.
Keep it small, keep it obvious.

## Stack

- Ruby on Rails 8.1.x, PostgreSQL
- Devise (auth), Pundit (authorization), Pay + Stripe (billing)
- HexaPDF (PDF generation — pure Ruby, no binary deps)
- Hotwire (Turbo + Stimulus), Tailwind CSS
- Slim templates (not ERB)
- Kamal (deployment), dotenv (local secrets)
- Rubocop, Brakeman, Bullet, Rubycritic (dev tooling)

## Development Commands

```
bin/setup          # install gems, create and migrate DB
bin/dev            # start dev server (Foreman: Rails + Tailwind watcher)
bin/rails console  # Rails console
```

Local URL: http://localhost:3000

## Testing

```
bin/rails test                          # run all tests
bin/rails test test/path/file_test.rb  # single file
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

```
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

### Models

Business logic goes in DRY models, use concerns, services and OOP. Service objects are not used.
If a method wraps one line with no explanation, inline it.
If a concern is used by only one model, inline it into the model.

### Controllers

Thin DRY controllers, use concerns, services and OOP. No logic beyond: authenticate, authorize, find record, respond.
Use standard CRUD actions. If you need a non-CRUD action, make it a new resource.

`Account::` namespace for anything scoped to `Current.user` (e.g., `Account::SubscriptionsController`).

### Views

Slim, not ERB. Use DRY helper methods to keep view clean and lean. All templates in `app/views/`.
Helpers take explicit arguments — no magical ivars inside helpers.
If a partial has no HTML (just Ruby), it belongs in a helper or model method.

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

## What this app is NOT

- Not a multi-tenant app
- Not a background job app
- Not an admin dashboard
- Not an API

If asked to add any of the above: decline, or raise it first. This is a demo.

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
