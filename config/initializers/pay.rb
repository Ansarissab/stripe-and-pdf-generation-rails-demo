# Pay.support_email= parses with Mail::Address, which isn't autoloaded yet.
require "mail"

Pay.setup do |config|
  config.application_name = "Stripe PDF Generation Demo"
  config.business_name    = "Stripe PDF Generation Demo"
  config.support_email    = "support@example.com"

  config.default_product_name = "subscription"
  config.default_plan_name    = "default"

  config.automount_routes = true
  config.routes_path      = "/pay"
end
