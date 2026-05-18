module PlanSync
  extend ActiveSupport::Concern

  ACTIVE_STATUSES = %w[active trialing].freeze

  included do
    after_save_commit :sync_user_plan
  end

  private

  # Recompute user.plan from *any* currently-active subscription the user owns,
  # not just the record being saved. Without this, an incomplete/canceled sub
  # save would clobber a still-active sub created earlier (common when users
  # retry a failed Checkout attempt and accumulate orphan subs).
  def sync_user_plan
    user = customer&.owner
    return unless user.is_a?(User)

    new_plan = derived_plan_for(user)
    new_value = new_plan && User.plans[new_plan]
    return if user.plan == new_plan&.to_s

    user.update_column(:plan, new_value)
  end

  def derived_plan_for(user)
    customer_ids = user.pay_customers.pluck(:id)
    return nil if customer_ids.empty?

    active = Pay::Subscription
              .where(customer_id: customer_ids, status: ACTIVE_STATUSES)
              .where("ends_at IS NULL OR ends_at > ?", Time.current)
              .order(created_at: :desc)
              .first
    return nil unless active

    case active.processor_plan
    when ENV["PAY_STRIPE_PLAN_BASIC"] then :basic
    when ENV["PAY_STRIPE_PLAN_PRO"]   then :pro
    end
  end
end
