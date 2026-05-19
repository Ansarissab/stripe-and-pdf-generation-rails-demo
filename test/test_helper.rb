ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require "webmock/minitest"

WebMock.disable_net_connect!(allow_localhost: true)

# Pay's Stripe adapter reads Stripe.api_key on first call. Stub it so the SDK
# doesn't raise about missing credentials when a test exercises the billing
# concern -- WebMock intercepts the HTTP request itself, so the value is moot.
Stripe.api_key = "sk_test_dummy" if defined?(Stripe)
ENV["PAY_STRIPE_PLAN_BASIC"] ||= "price_basic_test"
ENV["PAY_STRIPE_PLAN_PRO"]   ||= "price_pro_test"

Dir[Rails.root.join("test/support/**/*.rb")].each { |f| require f }

module ActiveSupport
  class TestCase
    parallelize(workers: :number_of_processors)

    # Per-worker SimpleCov bookkeeping. SimpleCov itself is started in
    # `config/boot.rb` BEFORE Rails -- that is what makes Coverage probes
    # actually fire for concerns mixed in via `to_prepare` (Billing, PlanSync).
    # Each worker tags its resultset with a unique name; SimpleCov merges them
    # at exit. Do NOT call `SimpleCov.at_fork.call(worker)` here -- it calls
    # `SimpleCov.start` again in the child, which detaches the inherited
    # Coverage probes from any file the parent had already loaded.
    parallelize_setup do |worker|
      SimpleCov.command_name "Worker-#{worker}"
    end

    parallelize_teardown do |_worker|
      SimpleCov.result
    end

    fixtures :all
  end
end

module ActionDispatch
  class IntegrationTest
    include Devise::Test::IntegrationHelpers
  end
end
