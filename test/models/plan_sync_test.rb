require "test_helper"

class PlanSyncTest < ActiveSupport::TestCase
  setup do
    @user     = users(:unsubscribed_user)
    @customer = setup_billing(@user)
  end

  test "active basic subscription sets users.plan to basic" do
    Pay::Stripe::Subscription.create!(
      customer: @customer, name: "default",
      processor_id: "sub_1", processor_plan: ENV["PAY_STRIPE_PLAN_BASIC"],
      status: "active"
    )
    assert_equal "basic", @user.reload.plan
  end

  test "active pro subscription sets users.plan to pro" do
    Pay::Stripe::Subscription.create!(
      customer: @customer, name: "default",
      processor_id: "sub_2", processor_plan: ENV["PAY_STRIPE_PLAN_PRO"],
      status: "active"
    )
    assert_equal "pro", @user.reload.plan
  end

  test "canceled subscription clears users.plan" do
    sub = Pay::Stripe::Subscription.create!(
      customer: @customer, name: "default",
      processor_id: "sub_3", processor_plan: ENV["PAY_STRIPE_PLAN_BASIC"],
      status: "active"
    )
    assert_equal "basic", @user.reload.plan

    sub.update!(status: "canceled", ends_at: 1.day.ago)
    assert_nil @user.reload.plan
  end

  test "unknown processor_plan leaves users.plan nil" do
    Pay::Stripe::Subscription.create!(
      customer: @customer, name: "default",
      processor_id: "sub_4", processor_plan: "price_unknown",
      status: "active"
    )
    assert_nil @user.reload.plan
  end
end
