# Stripe PDF Generation Demo

A small Rails 8.1 application demonstrating two capabilities:

1. **Two-tier Stripe subscription billing** (Basic / Pro) via the Pay gem.
2. **PDF generation** from subscription data via HexaPDF.

Everything sits behind Devise authentication. There are no public pages. The app is intentionally small — see [AGENTS.md](AGENTS.md) for the architectural rules it follows.

## Stack

| Layer | Choice |
| --- | --- |
| Framework | Rails 8.1, Ruby 4.0 |
| Database | PostgreSQL (Solid Queue / Solid Cache also on Postgres) |
| Auth | Devise + Pundit |
| Billing | Pay 11 + Stripe 19 (hosted billing portal, webhooks at `/pay/webhooks/stripe`) |
| PDFs | HexaPDF (pure Ruby, no native binaries) |
| Frontend | Hotwire (Turbo + Stimulus), Importmap |
| Styles | Tailwind v4, consolidated in `app/assets/tailwind/application.css` |
| Templates | Slim (no ERB) |
| Deploy | Kamal (Docker) or any buildpack host via `Procfile` |
| Dev tooling | Brakeman, Rubocop (rails-omakase), Bullet, bundler-audit, dotenv-rails |

## Prerequisites

- Ruby 4.0.0 (`.ruby-version`)
- PostgreSQL 14+
- A Stripe account with two recurring Prices (Basic + Pro) created in the dashboard

## Setup

```sh
bin/setup            # bundle install + db:create + db:migrate
cp .env.example .env # fill in your Stripe test keys + plan price IDs
bin/dev              # boots Puma + Tailwind watcher via Procfile.dev
```

The app is then at <http://localhost:3000>. Webhooks during local development:

```sh
stripe listen --forward-to localhost:3000/pay/webhooks/stripe
```

Take the `whsec_...` value the CLI prints and put it in `.env` as `STRIPE_WEBHOOK_SECRET`.

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
bin/rails test                          # everything
bin/rails test test/models/user_test.rb # one file
```

`db:test:prepare` runs implicitly before the suite.

## Code quality

```sh
bin/rubocop              # Rails Omakase style
bin/brakeman --no-pager  # security scan
bundle exec bundler-audit check --update
```

Bullet is enabled in development and writes N+1 warnings to `log/bullet.log` and the Rails log.

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
  controllers/   thin, before_action :authenticate_user!, authorize via Pundit
  models/        fat — business logic + concerns, no service objects
  pdfs/          plain Ruby classes that emit HexaPDF documents
  policies/      Pundit policies (one per resource)
  views/         Slim only
  assets/tailwind/application.css   single source of truth for design tokens + component classes
config/initializers/
  devise.rb      Devise config
  pay.rb         Pay.setup + Stripe env-var bridge
```

## Conventions

The non-obvious rules live in [AGENTS.md](AGENTS.md). The big ones:

- **Validation cascade**: DB → Model → Controller → View. Every layer is the last line of defense.
- **Tailwind**: shared classes live in one file, views reach for them before raw utilities.
- **Pay is the source of truth for subscription state**; `users.plan` is a cached column (Basic / Pro, nullable — a `nil` plan means the user hasn't subscribed yet).
- **No service objects, no background jobs, no admin UI**. This is a demo. New features get pushed back if they expand scope.
