module PlansHelper
  PLAN_BADGE_CLASSES = {
    "basic" => "bg-surface-muted border border-border text-text",
    "pro"   => "bg-brand text-white",
    nil     => "bg-alert-soft border border-alert text-alert"
  }.freeze

  def plan_badge(user)
    classes = PLAN_BADGE_CLASSES[user.plan]
    label   = user.plan&.titleize || "No active plan"
    content_tag(:span, label, class: "inline-block px-3 py-1 rounded-full text-sm font-medium #{classes}")
  end

  def plan_price_cents(plan_key)
    case plan_key
    when :basic then 900   # $9.00
    when :pro   then 2900  # $29.00
    end
  end

  def plan_price_label(plan_key)
    cents = plan_price_cents(plan_key)
    return "" unless cents

    "$#{format('%.2f', cents / 100.0)}/mo"
  end

  def plan_price_id(plan_key)
    case plan_key
    when :basic then ENV["PAY_STRIPE_PLAN_BASIC"]
    when :pro   then ENV["PAY_STRIPE_PLAN_PRO"]
    end
  end
end
