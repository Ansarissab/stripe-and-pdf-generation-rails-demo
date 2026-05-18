module Billing
  extend ActiveSupport::Concern

  # Start a Stripe-hosted Checkout session for a recurring subscription.
  # Returns the Stripe::Checkout::Session; caller redirects to its url.
  def start_hosted_checkout(price_id:, success_url:, cancel_url:)
    checkout(
      mode:        "subscription",
      line_items:  [ { price: price_id, quantity: 1 } ],
      success_url: success_url,
      cancel_url:  cancel_url
    )
  end

  # Create a default_incomplete Stripe subscription so the PaymentElement on
  # our page can confirm it. Returns the PaymentIntent client_secret to hand
  # to Stripe.js. Walks the Basil (2025-03-31) field rename + older shapes so
  # we tolerate API version drift.
  def start_embedded_subscription(price_id:)
    sub = Stripe::Subscription.create(
      customer:         materialized_stripe_id,
      items:            [ { price: price_id } ],
      payment_behavior: "default_incomplete",
      payment_settings: { save_default_payment_method: "on_subscription" },
      expand:           [ "latest_invoice.confirmation_secret" ]
    )
    extract_client_secret(sub) or
      raise Stripe::StripeError, "Stripe returned no client_secret for sub #{sub.id}"
  end

  def open_billing_portal(return_url:)
    billing_portal(return_url: return_url)
  end

  # Swap the plan on the existing active sub instead of creating a parallel
  # one. Stripe handles proration via `proration_behavior: create_prorations`
  # (default). No new payment intent / PaymentElement -- the existing payment
  # method on file is reused. Returns the updated Stripe::Subscription, or nil
  # if there's no active sub to swap (caller should fall through to a fresh
  # checkout).
  def swap_plan(price_id:)
    sub = active_subscription or return nil

    remote_sub = Stripe::Subscription.retrieve(sub.processor_id)
    Stripe::Subscription.update(
      sub.processor_id,
      items: [ { id: remote_sub.items.data.first.id, price: price_id } ],
      proration_behavior: "create_prorations"
    )
  end

  # Returns the current active subscription if any; falls back to the most
  # recent record (could be canceled/incomplete) so views can render history.
  def current_subscription
    active_subscription || subscriptions.order(created_at: :desc).first
  end

  def active_subscription
    subscriptions
      .where(status: PlanSync::ACTIVE_STATUSES)
      .where("ends_at IS NULL OR ends_at > ?", Time.current)
      .order(created_at: :desc)
      .first
  end

  private

  def materialized_stripe_id
    processor_id || customer.id
  end

  def extract_client_secret(stripe_sub)
    invoice = stripe_sub.latest_invoice
    return nil unless invoice

    secret = invoice.respond_to?(:confirmation_secret) && invoice.confirmation_secret&.client_secret
    return secret if secret.present?

    pi_id = invoice.respond_to?(:payment_intent) ? invoice.payment_intent : nil
    pi_id ||= invoice.payments&.data&.first&.payment&.payment_intent if invoice.respond_to?(:payments)
    return nil unless pi_id

    Stripe::PaymentIntent.retrieve(pi_id).client_secret
  end
end
