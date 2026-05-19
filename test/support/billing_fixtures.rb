module BillingFixtures
  # Wire a Pay::Stripe::Customer to a user with an optional active subscription.
  # Returns the Pay::Customer (with `:subscription` reader if a plan was passed).
  #
  # `plan:` accepts:
  #   nil      -- customer only, no subscription
  #   :basic   -- active subscription on PAY_STRIPE_PLAN_BASIC price id
  #   :pro     -- active subscription on PAY_STRIPE_PLAN_PRO  price id
  def setup_billing(user, plan: nil, processor_id: nil)
    processor_id ||= "cus_test_#{user.id}_#{SecureRandom.hex(3)}"
    customer = user.set_payment_processor(:stripe, processor_id: processor_id)

    return customer if plan.nil?

    price_id = plan_price_id(plan)
    subscription = Pay::Stripe::Subscription.create!(
      customer:       customer,
      name:           "default",
      processor_id:   "sub_test_#{user.id}_#{SecureRandom.hex(3)}",
      processor_plan: price_id,
      status:         "active"
    )
    customer.define_singleton_method(:subscription) { subscription }
    customer
  end

  # Build a Pay::Charge for the given customer. Used wherever a test needs an
  # invoice/charge to render or scope.
  def make_charge(customer, amount: 900, currency: "usd", processor_id: nil, **extra)
    Pay::Charge.create!(
      {
        customer:     customer,
        processor_id: processor_id || "ch_test_#{SecureRandom.hex(3)}",
        amount:       amount,
        currency:     currency
      }.merge(extra)
    )
  end

  private

  def plan_price_id(plan)
    case plan
    when :basic then ENV["PAY_STRIPE_PLAN_BASIC"]
    when :pro   then ENV["PAY_STRIPE_PLAN_PRO"]
    else raise ArgumentError, "unknown plan #{plan.inspect}"
    end
  end
end

ActiveSupport::TestCase.include(BillingFixtures)
