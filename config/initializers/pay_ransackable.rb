# Ransack 4 requires every AA-registered model to declare an explicit
# allowlist of searchable attributes + associations. The Pay gem's models
# live outside our codebase, so we re-open them here.
#
# Conservative allowlists: only the fields we actually filter / sort on in
# app/admin/pay_*.rb plus the foreign keys AA's index columns reference. The
# omitted fields are auth-adjacent (`data` jsonb, `metadata`, `object`, raw
# Stripe blobs) or processor-internal noise.
Rails.application.config.to_prepare do
  Pay::Customer.class_eval do
    def self.ransackable_attributes(_auth_object = nil)
      %w[id type owner_type owner_id processor processor_id default created_at updated_at deleted_at]
    end

    def self.ransackable_associations(_auth_object = nil)
      %w[subscriptions charges payment_methods]
    end
  end

  Pay::Subscription.class_eval do
    def self.ransackable_attributes(_auth_object = nil)
      %w[id type customer_id name processor_id processor_plan status quantity current_period_start current_period_end trial_ends_at ends_at pause_starts_at pause_resumes_at created_at updated_at]
    end

    def self.ransackable_associations(_auth_object = nil)
      %w[customer charges]
    end
  end

  Pay::Charge.class_eval do
    def self.ransackable_attributes(_auth_object = nil)
      %w[id type customer_id subscription_id amount amount_refunded currency processor_id application_fee_amount created_at updated_at]
    end

    def self.ransackable_associations(_auth_object = nil)
      %w[customer subscription]
    end
  end
end
