# Cascade Pay::Subscription state changes into the cached User#plan column.
# Pay persists its own records from Stripe webhooks; this callback fires on
# every save so the cache stays in lockstep regardless of source (webhook,
# console, test).
Rails.application.config.to_prepare do
  Pay::Subscription.include(PlanSync) unless Pay::Subscription.include?(PlanSync)
end
