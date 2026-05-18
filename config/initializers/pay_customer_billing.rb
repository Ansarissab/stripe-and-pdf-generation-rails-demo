# Add the subscription/checkout helpers to Pay::Customer AND its STI
# subclasses. Including only in the parent works in pure Ruby, but Pay's
# autoload order can leave Pay::Stripe::Customer with a stale ancestor chain
# in dev reload cycles -- belt-and-suspenders include guarantees the methods
# are available at call time.
Rails.application.config.to_prepare do
  [ Pay::Customer, Pay::Stripe::Customer ].each do |klass|
    klass.include(Billing) unless klass.include?(Billing)
  end
end
