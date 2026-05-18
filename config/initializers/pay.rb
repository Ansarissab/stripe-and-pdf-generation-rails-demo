# Bridge AGENTS.md / Stripe-dashboard naming to the env var names Pay reads
# internally. Pay looks up STRIPE_PRIVATE_KEY and STRIPE_SIGNING_SECRET, but the
# Stripe dashboard and CLI label the same values as "secret key" and "webhook
# signing secret", so the project standardises on STRIPE_SECRET_KEY and
# STRIPE_WEBHOOK_SECRET in .env / .env.example to avoid confusion. This is the
# one place those two vocabularies get reconciled.
ENV["STRIPE_PRIVATE_KEY"]    ||= ENV["STRIPE_SECRET_KEY"]
ENV["STRIPE_SIGNING_SECRET"] ||= ENV["STRIPE_WEBHOOK_SECRET"]

Pay.setup do |config|
  config.application_name = "Stripe PDF Generation Demo"
  config.business_name    = "Stripe PDF Generation Demo"
  config.support_email    = "support@example.com"

  config.default_product_name = "subscription"
  config.default_plan_name    = "default"

  # Mounts Pay's billing portal and webhook routes at /pay/* automatically.
  config.automount_routes = true
  config.routes_path      = "/pay"
end
