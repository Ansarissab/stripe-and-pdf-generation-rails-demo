require "test_helper"

class Pay::SubscriptionPolicyTest < ActiveSupport::TestCase
  setup do
    @user      = users(:basic_user)
    @other     = users(:pro_user)
    customer   = setup_billing(@user,  plan: :basic, processor_id: "cus_pol_owner")
    @sub       = customer.subscription
    setup_billing(@other, plan: :basic, processor_id: "cus_pol_other")
  end

  # --- class-mode (authorize Pay::Subscription, :create?) ------------------

  test "class-mode actions only require sign-in" do
    policy = Pay::SubscriptionPolicy.new(@user, Pay::Subscription)
    assert policy.create?
    assert policy.new?
    assert policy.index?
    assert policy.update?
    assert policy.billing_portal?

    refute policy.destroy?, "destroy? must be owned, not class-mode"
  end

  test "anonymous visitors are denied even class-mode actions" do
    policy = Pay::SubscriptionPolicy.new(nil, Pay::Subscription)
    refute policy.create?
    refute policy.update?
    refute policy.destroy?
    refute policy.billing_portal?
  end

  # --- instance-mode (authorize @subscription) -----------------------------

  test "owner may show, update, and destroy their own subscription" do
    policy = Pay::SubscriptionPolicy.new(@user, @sub)
    assert policy.show?
    assert policy.update?
    assert policy.destroy?
  end

  test "another user is denied destroy on someone else's subscription" do
    policy = Pay::SubscriptionPolicy.new(@other, @sub)
    refute policy.destroy?
  end
end
