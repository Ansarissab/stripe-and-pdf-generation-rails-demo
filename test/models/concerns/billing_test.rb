require "test_helper"

# Exercise the Billing concern mixed into Pay::Stripe::Customer. Every test
# stubs the underlying Stripe HTTP call via WebMock and asserts the concern's
# return value -- no Stripe SDK mocking, no service-object stand-ins.
class BillingTest < ActiveSupport::TestCase
  setup do
    @user     = users(:unsubscribed_user)
    @customer = setup_billing(@user)
  end

  test "start_hosted_checkout returns a Checkout Session with a redirect url" do
    stub_stripe_checkout_session(url: "https://checkout.stripe.com/c/pay/cs_test_abc")

    session = @customer.start_hosted_checkout(
      price_id:    ENV["PAY_STRIPE_PLAN_BASIC"],
      success_url: "https://example.test/account/subscription/success",
      cancel_url:  "https://example.test/account/subscription/cancel"
    )

    assert_equal "https://checkout.stripe.com/c/pay/cs_test_abc", session.url
  end

  test "start_embedded_subscription returns the Basil-shape client_secret" do
    stub_stripe_subscription_create(client_secret_shape: :basil)

    secret = @customer.start_embedded_subscription(price_id: ENV["PAY_STRIPE_PLAN_BASIC"])
    assert_equal "pi_test_1_secret_basil", secret
  end

  test "start_embedded_subscription walks the legacy payment_intent shape" do
    stub_stripe_subscription_create(client_secret_shape: :legacy_intent)
    stub_stripe_payment_intent_retrieve(id: "pi_test_legacy", client_secret: "pi_test_legacy_secret_xyz")

    secret = @customer.start_embedded_subscription(price_id: ENV["PAY_STRIPE_PLAN_BASIC"])
    assert_equal "pi_test_legacy_secret_xyz", secret
  end

  test "start_embedded_subscription walks the multi-payment fallback shape" do
    stub_stripe_subscription_create(client_secret_shape: :multi_payment)
    stub_stripe_payment_intent_retrieve(id: "pi_test_multi", client_secret: "pi_test_multi_secret_abc")

    secret = @customer.start_embedded_subscription(price_id: ENV["PAY_STRIPE_PLAN_BASIC"])
    assert_equal "pi_test_multi_secret_abc", secret
  end

  test "start_embedded_subscription raises when Stripe returns no client_secret" do
    stub_stripe_subscription_create(client_secret_shape: :missing)

    assert_raises(Stripe::StripeError) do
      @customer.start_embedded_subscription(price_id: ENV["PAY_STRIPE_PLAN_BASIC"])
    end
  end

  test "open_billing_portal returns a portal session url" do
    stub_stripe_billing_portal_session(url: "https://billing.stripe.com/p/session/abc")

    portal = @customer.open_billing_portal(return_url: "https://example.test/account/subscription")
    assert_equal "https://billing.stripe.com/p/session/abc", portal.url
  end

  test "current_subscription prefers the active sub over a canceled one" do
    Pay::Stripe::Subscription.create!(
      customer: @customer, name: "default",
      processor_id: "sub_old", processor_plan: ENV["PAY_STRIPE_PLAN_BASIC"],
      status: "canceled", ends_at: 1.day.ago
    )
    active = Pay::Stripe::Subscription.create!(
      customer: @customer, name: "default",
      processor_id: "sub_now", processor_plan: ENV["PAY_STRIPE_PLAN_PRO"],
      status: "active"
    )

    assert_equal active, @customer.reload.current_subscription
  end

  test "current_subscription falls back to the most recent sub when none active" do
    canceled = Pay::Stripe::Subscription.create!(
      customer: @customer, name: "default",
      processor_id: "sub_only", processor_plan: ENV["PAY_STRIPE_PLAN_BASIC"],
      status: "canceled", ends_at: 1.day.ago
    )

    assert_equal canceled, @customer.reload.current_subscription
  end

  test "swap_plan updates the existing Stripe sub instead of creating a new one" do
    Pay::Stripe::Subscription.create!(
      customer: @customer, name: "default",
      processor_id: "sub_existing", processor_plan: ENV["PAY_STRIPE_PLAN_BASIC"],
      status: "active"
    )
    stub_stripe_subscription_retrieve(id: "sub_existing", price_id: ENV["PAY_STRIPE_PLAN_BASIC"])
    update_stub = stub_stripe_subscription_update(id: "sub_existing", new_price_id: ENV["PAY_STRIPE_PLAN_PRO"])

    @customer.swap_plan(price_id: ENV["PAY_STRIPE_PLAN_PRO"])

    assert_requested(update_stub)
  end

  test "swap_plan returns nil when there's no active sub to swap" do
    assert_nil @customer.swap_plan(price_id: ENV["PAY_STRIPE_PLAN_PRO"])
  end
end
