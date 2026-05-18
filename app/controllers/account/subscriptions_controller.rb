class Account::SubscriptionsController < ApplicationController
  before_action :ensure_billing,    only: %i[create embedded destroy billing_portal]
  before_action :set_subscription,  only: %i[show destroy]

  def show
    authorize(@subscription || Pay::Subscription, policy_class: Pay::SubscriptionPolicy)
  end

  def new
    authorize Pay::Subscription, :create?, policy_class: Pay::SubscriptionPolicy
  end

  def create
    authorize Pay::Subscription, :create?, policy_class: Pay::SubscriptionPolicy
    price_id = resolved_price_id or return missing_plan_redirect

    if billing.active_subscription
      billing.swap_plan(price_id: price_id)
      redirect_to account_subscription_path,
                  notice: "Plan updated. Stripe prorated the change; the new amount will appear on your next invoice."
    else
      session = billing.start_hosted_checkout(
        price_id:    price_id,
        success_url: absolute_url(success_account_subscription_path),
        cancel_url:  absolute_url(cancel_account_subscription_path)
      )
      redirect_to session.url, allow_other_host: true
    end
  rescue Stripe::StripeError => e
    stripe_failure_redirect(e)
  end

  def embedded
    authorize Pay::Subscription, :create?, policy_class: Pay::SubscriptionPolicy
    price_id = resolved_price_id or return missing_plan_redirect

    # Already on a plan -> swap server-side, no PaymentElement needed (the
    # existing payment method on file is reused).
    if billing.active_subscription
      billing.swap_plan(price_id: price_id)
      return redirect_to(account_subscription_path,
                         notice: "Plan updated inline. The new amount will appear on your next invoice.")
    end

    @client_secret = billing.start_embedded_subscription(price_id: price_id)
    @plan          = params[:plan].to_sym
    render :embedded
  rescue Stripe::StripeError => e
    stripe_failure_redirect(e)
  end

  def destroy
    return redirect_to(account_subscription_path, alert: "No active subscription to cancel.") unless @subscription

    authorize @subscription, policy_class: Pay::SubscriptionPolicy
    @subscription.cancel
    redirect_to account_subscription_path,
                notice: "Subscription will end on #{@subscription.reload.ends_at&.to_date || 'the period end'}."
  rescue Pay::Error, Stripe::StripeError => e
    redirect_to account_subscription_path, alert: "Couldn't cancel: #{e.message}"
  end

  def success
    redirect_to account_subscription_path,
                notice: "Thanks! Your subscription is being activated. The page below updates the moment Stripe confirms."
  end

  def cancel
    redirect_to new_account_subscription_path,
                alert: "Subscription wasn't completed. You can try again any time."
  end

  def billing_portal
    authorize Pay::Subscription, :billing_portal?, policy_class: Pay::SubscriptionPolicy
    portal = billing.open_billing_portal(return_url: absolute_url(account_subscription_path))
    redirect_to portal.url, allow_other_host: true
  rescue Pay::Error, Stripe::StripeError => e
    redirect_to account_subscription_path, alert: "Couldn't open billing portal: #{e.message}"
  end

  private

  def billing
    current_user.payment_processor
  end

  def ensure_billing
    current_user.set_payment_processor(:stripe) if current_user.payment_processor.nil?
  end

  def set_subscription
    @subscription = current_user.payment_processor&.current_subscription
  end

  def resolved_price_id
    helpers.plan_price_id(params[:plan]&.to_sym)
  end

  def missing_plan_redirect
    redirect_to new_account_subscription_path, alert: "Pick Basic or Pro to continue."
  end

  def stripe_failure_redirect(error)
    Rails.logger.error("[#{action_name}] #{error.class}: #{error.message}")
    redirect_to new_account_subscription_path, alert: "Stripe error: #{error.message}"
  end

  def absolute_url(path)
    request.base_url.chomp("/") + path
  end
end
