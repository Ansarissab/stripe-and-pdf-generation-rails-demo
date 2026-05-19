# Stripe PDF Generation Demo

A small Rails 8.1 application demonstrating four capabilities:

1. **Two-tier Stripe subscription billing** (Basic / Pro) via the Pay gem.
2. **PDF generation** from subscription data via HexaPDF.
3. **Minimal admin panel** via ActiveAdmin at `/admin` (separate `AdminUser` Devise scope).
4. **Internationalisation** — English + French, switched via a header toggle. Every user-facing string lives in `config/locales/` (`en.yml` + `fr.yml`); a third locale is a YAML-only change.

Everything sits behind Devise authentication. End-users go through the `User` scope; the admin panel goes through the isolated `AdminUser` scope. There are no public pages. The app is intentionally small — see [AGENTS.md](AGENTS.md) for the architectural rules it follows.

## Stack

| Layer | Choice |
| --- | --- |
| Framework | Rails 8.1, Ruby 4.0 |
| Database | PostgreSQL (Solid Queue / Solid Cache also on Postgres) |
| Auth | Devise (`User` + `AdminUser` scopes) + Pundit |
| Billing | Pay 11 + Stripe 19 (hosted billing portal, webhooks at `/pay/webhooks/stripe`) |
| PDFs | HexaPDF (pure Ruby, no native binaries) |
| Admin | ActiveAdmin 3.5 mounted at `/admin` (read-only on business data) |
| I18n | Rails I18n — `en.yml` + `fr.yml` (app) and matching `devise.*.yml` files; toggle in the header switches locale per session |
| Frontend | Hotwire (Turbo + Stimulus), Importmap |
| Styles | Tailwind v4, consolidated in `app/assets/tailwind/application.css` (AA still uses Sprockets/Sassc) |
| Templates | Slim (no ERB) |
| Deploy | Kamal (Docker) or any buildpack host via `Procfile` |
| Dev tooling | Brakeman, Rubocop (rails-omakase), Bullet, bundler-audit, dotenv-rails |

## Prerequisites

- Ruby 4.0.0 (`.ruby-version`)
- PostgreSQL 14+
- A Stripe account with two recurring Prices (Basic + Pro) created in the dashboard

## Setup

```sh
bin/setup            # bundle install + db:create + db:migrate + ActiveAdmin CSS + git hooks
cp .env.example .env # fill in your Stripe test keys + plan price IDs
bin/rails db:seed    # optional: 3 confirmed end-users + demo billing rows + 1 admin
bin/dev              # boots Puma on :3200 + Tailwind watcher via Procfile.dev
```

`bin/setup` also compiles ActiveAdmin's SCSS into `app/assets/builds/active_admin.css` so Propshaft can serve it (it doesn't process `.scss`). If you ever edit `app/assets/stylesheets/active_admin.scss`, re-run `bin/rails active_admin:build_css` — the task is also `enhance`d onto `assets:precompile` for production builds.

Seeded credentials (all use password `password`):

| Account | Email | Purpose |
| --- | --- | --- |
| End-user (no plan) | `nobody@example.test` | Signs up but never subscribes |
| End-user (Basic) | `basic@example.test` | Has a Basic subscription + one charge |
| End-user (Pro) | `pro@example.test` | Has a Pro subscription + one charge |
| Admin | `admin@example.test` | Logs in at `/admin/login`, dev-only |

The language toggle (English / Français) lives in the header on every authenticated page; the selection is stored in the session and survives until sign-out.

The app is then at <http://localhost:3200> (the dev port default — see `bin/dev`). Webhooks during local development:

```sh
stripe listen --forward-to localhost:3200/pay/webhooks/stripe
```

Take the `whsec_...` value the CLI prints and put it in `.env` as `STRIPE_SIGNING_SECRET`. The full integration runbook (every Stripe-related error we've hit and how we fixed it, plus production checklist) lives in [docs/stripe_integration/README.md](docs/stripe_integration/README.md).

Dev confirmation emails go to **letter_opener_web** — visit <http://localhost:3200/letter_opener> to read them.

## Environment variables

`.env` is local-only and never committed; `.env.example` is the template. See it for the full list. The required keys are:

| Key | What it is |
| --- | --- |
| `STRIPE_PUBLIC_KEY` | Publishable key from Stripe dashboard |
| `STRIPE_PRIVATE_KEY` | Stripe "Secret key" — name follows Pay's convention |
| `STRIPE_SIGNING_SECRET` | Webhook endpoint signing secret |
| `PAY_STRIPE_PLAN_BASIC` | Stripe Price ID for the Basic tier |
| `PAY_STRIPE_PLAN_PRO` | Stripe Price ID for the Pro tier |
| `SECRET_KEY_BASE` | Generate with `bin/rails secret` |
| `DATABASE_URL` | Optional — overrides `config/database.yml`. Leave unset in development to use the local Postgres socket with your OS user. |

Production secrets are loaded by Kamal from `.kamal/secrets` (gitignored), not from `.env`.

## Tests

Minitest with fixtures (no factories, per [AGENTS.md](AGENTS.md)).

```sh
bin/rails test                          # everything (parallel)
bin/rails test test/models/user_test.rb # one file
```

`db:test:prepare` runs implicitly before the suite. The runner parallelises across CPU cores.

SimpleCov writes a line-coverage report to `coverage/index.html` on every run. A 90% minimum is the gate (added once Agent D's parallel-coverage fix lands). The whole `coverage/` folder is gitignored — it is regenerated per run.

New tests mirror `app/` 1:1 under `test/` (`controllers/`, `models/`, `policies/`, `pdfs/`, `views/`). Shared helpers — WebMock stubs for Stripe REST endpoints, Pay STI fixtures — live in `test/support/` and are auto-required by `test_helper.rb`. Add to the existing helper files rather than creating new ones.

The full rules (mocking at the boundary, no factory_bot, Pundit testing pattern) live in the **Testing architecture** section of [AGENTS.md](AGENTS.md). Test-time Stripe gotchas (Pay STI scoping, cancel-stub double-field requirement, SimpleCov + parallel testing) are catalogued in [docs/stripe_integration/README.md §9](docs/stripe_integration/README.md#9-troubleshooting--every-error-we-hit-in-order).

## Code quality

```sh
bin/rubocop              # Rails Omakase style
bin/brakeman --no-pager  # security scan
bundle exec bundler-audit check --update
bin/importmap audit      # JS dependency scan
bin/ci                   # run everything above in one shot
```

Bullet is enabled in development and writes N+1 warnings to `log/bullet.log` and the Rails log.

### Pre-commit hook

`bin/setup` wires up `.githooks/pre-commit`, which runs the same four checks GitHub Actions runs (rubocop, brakeman, bundler-audit, importmap audit). A failing check aborts the commit. Bypass in a true emergency with `git commit --no-verify`.

If you cloned the repo without running `bin/setup`, install the hook with:

```sh
git config core.hooksPath .githooks
```

## Deployment

Two paths are supported and both run the same DB-migrate contract.

**Kamal / Docker** — `kamal deploy`. The Dockerfile is multi-stage with BuildKit cache mounts (apt, bundler, bootsnap), so incremental builds are fast. `bin/docker-entrypoint` runs migrations on boot.

**Buildpack PaaS** — Heroku, Render, Fly Procfile mode, etc. The `Procfile` declares:

```procfile
web:     bundle exec puma -C config/puma.rb
release: bin/rails db:migrate
```

## Project layout (highlights)

```text
app/
  admin/                           ActiveAdmin DSL registrations (read-only on business data)
    dashboard.rb                   3-panel summary: Users, Active subs, Charges this month
    users.rb, pay_*.rb             Read-only index/show for User and Pay::* records
    admin_users.rb                 Full CRUD on AdminUser itself
  controllers/
    account/                       Anything scoped to current_user (subscription, invoices)
    home_controller.rb             Signed-in landing page
  models/                          Fat — business logic + concerns, no service objects
    admin_user.rb                  Devise-only auth model for the /admin panel
    concerns/plan_sync.rb          Mirrors Pay::Subscription state -> users.plan cache column
  pdfs/                            Plain Ruby classes that emit HexaPDF documents (i18n via `pdf.*`)
  policies/
    pay/                           Pundit policies for Pay::Subscription, Pay::Charge
  javascript/controllers/
    stripe_elements_controller.js  Mounts Stripe Elements PaymentElement for the embedded flow
  views/                           Slim only — no hardcoded English; every label uses `t(".key")`
  assets/tailwind/application.css  Single source of truth for design tokens + component classes
config/initializers/
  active_admin.rb                  ActiveAdmin config (site title, default namespace = :admin)
  devise.rb                        Devise config
  pay.rb                           Pay.setup (auto-mounts /pay/webhooks/stripe)
  pay_subscription_sync.rb         Hooks PlanSync into Pay::Subscription
config/locales/
  en.yml                           App-owned strings: nav, plans, account/*, pdf, flash
  devise.en.yml                    Devise upstream catalogue + extended view-side keys
lib/tasks/
  subscriptions.rake               flush_orphans + resync_from_stripe maintenance tasks
docs/stripe_integration/           Full Stripe + Pay runbook (setup, errors, fixes, prod checklist)
```

The two account-scoped routes:

```text
GET    /account/subscription              show current sub (or "Choose a plan")
GET    /account/subscription/new          plan picker, two flows side-by-side
POST   /account/subscription              hosted Stripe Checkout
POST   /account/subscription/embedded     embedded Stripe Elements (PaymentElement)
DELETE /account/subscription              cancel at period end
POST   /account/subscription/billing_portal   redirect to Stripe-hosted portal
GET    /account/invoices                  list of Pay::Charge rows
GET    /account/invoices/:id              streams an InvoicePdf via send_data
```

The admin panel (Devise-scoped to `AdminUser`):

```text
GET    /admin/login                       AdminUser sign-in
GET    /admin                             Dashboard (3 summary panels)
GET    /admin/users                       End-user index (read-only)
GET    /admin/pay_customers               Pay::Customer index (read-only)
GET    /admin/pay_subscriptions           Pay::Subscription index (read-only)
GET    /admin/pay_charges                 Pay::Charge index (read-only)
GET    /admin/admin_users                 AdminUser CRUD
```

## Conventions

The non-obvious rules live in [AGENTS.md](AGENTS.md). The big ones:

- **Validation cascade**: DB → Model → Controller → View. Every layer is the last line of defense.
- **Tailwind**: shared classes live in one file, views reach for them before raw utilities.
- **Pay is the source of truth for subscription state**; `users.plan` is a cached column (Basic / Pro, nullable — a `nil` plan means the user hasn't subscribed yet).
- **No service objects, no background jobs.** This is a demo. New features get pushed back if they expand scope.
- **`Account::` namespace** for everything scoped to `current_user` (the user's own subscription, invoices, etc.).
- **Admin is read-only on business data.** The ActiveAdmin panel at `/admin` registers `User` / `Pay::*` with `actions :index, :show` only — no `permit_params`. The only mutable resource is `AdminUser` itself. Don't grow it into a customer-data CRUD; fix data in Stripe, not in our DB.
- **I18n is mandatory for any user-facing string.** Views, controllers, helpers, PDFs, mailers — every English word goes through `t(".key")`. App-owned strings live in [config/locales/en.yml](config/locales/en.yml); Devise's catalogue is in [config/locales/devise.en.yml](config/locales/devise.en.yml). Keys ending in `_html` are auto-marked safe; use that suffix for any string containing `'`, `&`, or inline HTML.

## Maintenance tasks

```sh
bin/rails subscriptions:flush_orphans       # cancel incomplete subs in Stripe + delete local rows, resync users.plan
bin/rails subscriptions:resync_from_stripe  # pull every customer's subs from Stripe and upsert locally
```

Use the first when failed Checkout attempts have left orphan `incomplete` subs; use the second when the local DB has drifted from Stripe (e.g. after a fresh `db:reset`).
