# Idempotent seed data. Run with: `bin/rails db:seed`.
#
# Three confirmed users + (for the two subscribed ones) a fake Pay::Customer,
# Pay::Subscription and one Pay::Charge so the dashboard, invoices list and
# PDF download all have something to render WITHOUT going through Stripe.
# Real flows (hosted Checkout / embedded Elements) still populate via webhooks
# in dev; this is purely a "click around the demo with no Stripe round-trip"
# convenience.

USERS = [
  { email: "nobody@example.test", plan: nil,                 demo_billing: false },
  { email: "basic@example.test",  plan: User.plans[:basic],  demo_billing: true, price_env: "PAY_STRIPE_PLAN_BASIC", amount: 999  },
  { email: "pro@example.test",    plan: User.plans[:pro],    demo_billing: true, price_env: "PAY_STRIPE_PLAN_PRO",   amount: 2999 }
].freeze

USERS.each do |attrs|
  user = User.find_or_initialize_by(email: attrs[:email])
  user.password = "password" if user.new_record? || user.encrypted_password.blank?
  user.confirmed_at ||= Time.current
  user.plan = attrs[:plan]
  user.save!

  next unless attrs[:demo_billing]

  customer = user.pay_customers.find_or_create_by!(processor: "stripe", type: "Pay::Stripe::Customer") do |c|
    c.processor_id = "cus_seed_#{user.id}"
    c.default      = true
  end

  price_id = ENV[attrs[:price_env]].presence || "price_seed_#{attrs[:plan]}"

  subscription = Pay::Subscription.find_or_create_by!(processor_id: "sub_seed_#{user.id}") do |s|
    s.customer             = customer
    s.name                 = "subscription"
    s.processor_plan       = price_id
    s.quantity             = 1
    s.status               = "active"
    s.current_period_start = Time.current.beginning_of_day
    s.current_period_end   = 1.month.from_now.beginning_of_day
    s.type                 = "Pay::Stripe::Subscription"
  end

  Pay::Charge.find_or_create_by!(processor_id: "ch_seed_#{user.id}") do |ch|
    ch.customer       = customer
    ch.subscription   = subscription
    ch.amount         = attrs[:amount]
    ch.currency       = "usd"
    ch.type           = "Pay::Stripe::Charge"
    ch.amount_refunded = 0
  end
end

puts "Seeded #{User.count} users, #{Pay::Customer.count} pay_customers, #{Pay::Subscription.count} subscriptions, #{Pay::Charge.count} charges."
