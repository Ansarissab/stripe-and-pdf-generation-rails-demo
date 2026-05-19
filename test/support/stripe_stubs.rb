# WebMock stub helpers for the Stripe REST endpoints the Billing concern hits.
#
# Stripe's SDK serialises POST bodies as form-encoded `application/x-www-form-urlencoded`
# and reads JSON back. We don't try to match exact bodies (the SDK adds extra params we
# don't care about); we match on method + URL and return fixture-shaped JSON.
module StripeStubs
  STRIPE_API = "https://api.stripe.com"

  def stub_stripe_checkout_session(url: "https://checkout.stripe.com/c/pay/cs_test_123", id: "cs_test_123")
    stub_request(:post, "#{STRIPE_API}/v1/checkout/sessions")
      .to_return(
        status:  200,
        body:    {
          id:     id,
          object: "checkout.session",
          mode:   "subscription",
          url:    url
        }.to_json,
        headers: { "Content-Type" => "application/json" }
      )
  end

  # Subscription create. Pass :client_secret_shape to control which API-version
  # shape `extract_client_secret` will walk:
  #   :basil          -- modern shape, latest_invoice.confirmation_secret.client_secret
  #   :legacy_intent  -- latest_invoice.payment_intent (string id) -> PaymentIntent.retrieve
  #   :multi_payment  -- latest_invoice.payments.data[0].payment.payment_intent -> retrieve
  #   :missing        -- no latest_invoice at all (drives the StripeError raise path)
  def stub_stripe_subscription_create(id: "sub_test_new", price_id: "price_basic_test", client_secret_shape: :basil)
    invoice =
      case client_secret_shape
      when :basil
        {
          id:                  "in_test_1",
          confirmation_secret: { client_secret: "pi_test_1_secret_basil" }
        }
      when :legacy_intent
        {
          id:             "in_test_1",
          payment_intent: "pi_test_legacy"
        }
      when :multi_payment
        {
          id:       "in_test_1",
          payments: { data: [ { payment: { payment_intent: "pi_test_multi" } } ] }
        }
      when :missing
        nil
      else
        raise ArgumentError, "unknown client_secret_shape #{client_secret_shape}"
      end

    stub_request(:post, "#{STRIPE_API}/v1/subscriptions")
      .to_return(
        status:  200,
        body:    {
          id:             id,
          object:         "subscription",
          status:         "incomplete",
          customer:       "cus_test_owner",
          items:          { data: [ { id: "si_test_1", price: { id: price_id } } ] },
          latest_invoice: invoice
        }.to_json,
        headers: { "Content-Type" => "application/json" }
      )
  end

  def stub_stripe_payment_intent_retrieve(id:, client_secret:)
    stub_request(:get, "#{STRIPE_API}/v1/payment_intents/#{id}")
      .to_return(
        status:  200,
        body:    {
          id:            id,
          object:        "payment_intent",
          client_secret: client_secret
        }.to_json,
        headers: { "Content-Type" => "application/json" }
      )
  end

  def stub_stripe_subscription_retrieve(id:, item_id: "si_test_1", price_id: "price_basic_test")
    stub_request(:get, "#{STRIPE_API}/v1/subscriptions/#{id}")
      .to_return(
        status:  200,
        body:    {
          id:       id,
          object:   "subscription",
          status:   "active",
          items:    { data: [ { id: item_id, price: { id: price_id } } ] }
        }.to_json,
        headers: { "Content-Type" => "application/json" }
      )
  end

  def stub_stripe_subscription_update(id:, new_price_id: "price_pro_test")
    stub_request(:post, "#{STRIPE_API}/v1/subscriptions/#{id}")
      .to_return(
        status:  200,
        body:    {
          id:     id,
          object: "subscription",
          status: "active",
          items:  { data: [ { id: "si_test_1", price: { id: new_price_id } } ] }
        }.to_json,
        headers: { "Content-Type" => "application/json" }
      )
  end

  # Pay's `subscription.cancel` (no args) does a `cancel_at_period_end=true`
  # POST against /v1/subscriptions/{id}, not a DELETE. DELETE is only used for
  # `cancel_now!`. Pay reads `cancel_at` from the response to set ends_at, so
  # leaving it out raises `TypeError` deep in `Time.at(nil)`.
  def stub_stripe_subscription_cancel(id:, cancel_at: 1.month.from_now.to_i)
    stub_request(:post, "#{STRIPE_API}/v1/subscriptions/#{id}")
      .to_return(
        status:  200,
        body:    {
          id:        id,
          object:    "subscription",
          status:    "active",
          cancel_at: cancel_at,
          cancel_at_period_end: true
        }.to_json,
        headers: { "Content-Type" => "application/json" }
      )
  end

  def stub_stripe_billing_portal_session(url: "https://billing.stripe.com/p/session/test_123")
    stub_request(:post, "#{STRIPE_API}/v1/billing_portal/sessions")
      .to_return(
        status:  200,
        body:    {
          id:     "bps_test_123",
          object: "billing_portal.session",
          url:    url
        }.to_json,
        headers: { "Content-Type" => "application/json" }
      )
  end

  def stub_stripe_error(method:, path:, status: 402, message: "Your card was declined.", code: "card_declined")
    stub_request(method, "#{STRIPE_API}#{path}")
      .to_return(
        status:  status,
        body:    {
          error: { type: "card_error", code: code, message: message }
        }.to_json,
        headers: { "Content-Type" => "application/json" }
      )
  end
end

ActiveSupport::TestCase.include(StripeStubs)
