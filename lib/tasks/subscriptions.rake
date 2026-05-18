namespace :subscriptions do
  desc "Cancel incomplete/incomplete_expired Stripe subs and delete local Pay::Subscription rows. Resyncs users.plan from remaining active subs."
  task flush_orphans: :environment do
    require "stripe"

    Pay::Subscription.where(status: %w[incomplete incomplete_expired canceled]).find_each do |sub|
      processor_id = sub.processor_id
      puts "  cancel  #{processor_id} (status=#{sub.status})"
      begin
        Stripe::Subscription.cancel(processor_id) if processor_id.start_with?("sub_")
      rescue Stripe::InvalidRequestError => e
        puts "    skip Stripe cancel: #{e.message}"
      end
      sub.destroy
    end

    User.find_each do |user|
      next unless user.payment_processor

      active = user.payment_processor.subscriptions
                    .where(status: PlanSync::ACTIVE_STATUSES)
                    .where("ends_at IS NULL OR ends_at > ?", Time.current)
                    .order(created_at: :desc)
                    .first

      derived =
        case active&.processor_plan
        when ENV["PAY_STRIPE_PLAN_BASIC"] then User.plans[:basic]
        when ENV["PAY_STRIPE_PLAN_PRO"]   then User.plans[:pro]
        end

      next if user.plan == (User.plans.key(derived))

      user.update_column(:plan, derived)
      puts "  user #{user.email} -> plan=#{User.plans.key(derived) || 'nil'}"
    end

    puts "done"
  end

  desc "Pull all Stripe subscriptions for every Pay::Customer and reconcile local Pay::Subscription rows."
  task resync_from_stripe: :environment do
    Pay::Customer.find_each do |customer|
      next unless customer.processor_id

      remote = Stripe::Subscription.list(customer: customer.processor_id, status: "all", limit: 100).data
      puts "#{customer.processor_id}: #{remote.size} stripe sub(s)"
      remote.each do |s|
        local = Pay::Subscription.find_or_initialize_by(processor_id: s.id)
        local.customer        = customer
        local.name            = "subscription"
        local.processor_plan  = s.items.data.first.price.id
        local.quantity        = s.items.data.first.quantity
        local.status          = s.status
        local.current_period_start = (s.items.data.first.current_period_start && Time.at(s.items.data.first.current_period_start))
        local.current_period_end   = (s.items.data.first.current_period_end   && Time.at(s.items.data.first.current_period_end))
        local.ends_at         = s.canceled_at ? Time.at(s.canceled_at) : nil
        local.save!
      end
    end
    puts "done"
  end
end
