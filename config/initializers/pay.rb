# Project uses STRIPE_SECRET_KEY / STRIPE_WEBHOOK_SECRET (Stripe dashboard
# labels); Pay reads STRIPE_PRIVATE_KEY / STRIPE_SIGNING_SECRET. Bridged here.
ENV["STRIPE_PRIVATE_KEY"]    ||= ENV["STRIPE_SECRET_KEY"]
ENV["STRIPE_SIGNING_SECRET"] ||= ENV["STRIPE_WEBHOOK_SECRET"]

Pay.setup do |config|
  config.application_name = "Stripe PDF Generation Demo"
  config.business_name    = "Stripe PDF Generation Demo"
  config.support_email    = "support@example.com"

  config.default_product_name = "subscription"
  config.default_plan_name    = "default"

  config.automount_routes = true
  config.routes_path      = "/pay"
end
