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
      redirect_to account_subscription_path, notice: t(".plan_updated")
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
                         notice: t("account.subscriptions.embedded_action.plan_updated"))
    end

    @client_secret = billing.start_embedded_subscription(price_id: price_id)
    @plan          = params[:plan].to_sym
    render :embedded
  rescue Stripe::StripeError => e
    stripe_failure_redirect(e)
  end

  def destroy
    return redirect_to(account_subscription_path, alert: t(".no_active")) unless @subscription

    authorize @subscription, policy_class: Pay::SubscriptionPolicy
    @subscription.cancel
    end_date = @subscription.reload.ends_at&.to_date || t(".period_end_fallback")
    redirect_to account_subscription_path,
                notice: t(".canceled_at", date: end_date)
  rescue Pay::Error, Stripe::StripeError => e
    redirect_to account_subscription_path, alert: t(".cancel_error", message: e.message)
  end

  def success
    redirect_to account_subscription_path, notice: t(".thanks")
  end

  def cancel
    redirect_to new_account_subscription_path,
                alert: t("account.subscriptions.cancel_action.wasnt_completed")
  end

  def billing_portal
    authorize Pay::Subscription, :billing_portal?, policy_class: Pay::SubscriptionPolicy
    portal = billing.open_billing_portal(return_url: absolute_url(account_subscription_path))
    redirect_to portal.url, allow_other_host: true
  rescue Pay::Error, Stripe::StripeError => e
    redirect_to account_subscription_path, alert: t(".portal_error", message: e.message)
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
    redirect_to new_account_subscription_path,
                alert: t("account.subscriptions.create.missing_plan")
  end

  def stripe_failure_redirect(error)
    Rails.logger.error("[#{action_name}] #{error.class}: #{error.message}")
    redirect_to new_account_subscription_path,
                alert: t("account.subscriptions.create.stripe_error", message: error.message)
  end

  def absolute_url(path)
    request.base_url.chomp("/") + path
  end
end
