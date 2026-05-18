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

```
bundle exec brakeman --no-pager
bundle exec rubocop
```

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

### Subscriptions

Pay gem wraps Stripe. Two plans: Basic and Pro.
Plan logic lives on the `User` model and `SubscriptionsController`.
Billing portal handled via Pay's built-in routes.

Users have a `pay_customer` — delegate to it, don't reinvent.

### PDF Generation

HexaPDF generates PDFs on the fly. No stored files for this demo.
PDF logic lives in `app/pdfs/` as plain Ruby classes.
Controllers stream the result directly with `send_data`.

Do not use background jobs for PDF generation in this demo — it is synchronous and instant.

### Models

Business logic goes in DRY models, use concerns, services and OOP. Service objects are not used.
If a method wraps one line with no explanation, inline it.
If a concern is used by only one model, inline it into the model.

### Controllers

Thin DRY controllers, use concerns, services and OOP. No logic beyond: authenticate, authorize, find record, respond.
Use standard CRUD actions. If you need a non-CRUD action, make it a new resource.

`My::` namespace for anything scoped to `Current.user` (e.g., `My::SubscriptionsController`).

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

## Coding Philosophy (37signals style)

**Abstractions must earn their keep.**
If you can't name 3+ cases that need an abstraction, inline it.

**Compute at write time, not read time.**
Store derived values on save. Don't compute in views or serializers.

**DB constraints over AR validations.**
Use `add_index ..., unique: true` and foreign keys in migrations.
Only add AR validations when you need a user-facing form error.

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

```
STRIPE_PUBLIC_KEY
STRIPE_SECRET_KEY
STRIPE_WEBHOOK_SECRET
PAY_STRIPE_PLAN_BASIC
PAY_STRIPE_PLAN_PRO
DATABASE_URL
SECRET_KEY_BASE
```
