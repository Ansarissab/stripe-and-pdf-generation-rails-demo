require "test_helper"

class Account::SubscriptionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user  = users(:unsubscribed_user)
    @other = users(:basic_user)
  end

  # --- new -----------------------------------------------------------------

  test "new renders the plan picker" do
    sign_in @user
    get new_account_subscription_url
    assert_response :success
    assert_select "h1", /Choose a plan/i
  end

  # --- create (hosted Checkout) -------------------------------------------

  test "create redirects to Stripe Checkout when there is no active sub" do
    setup_billing(@user)
    stub_stripe_checkout_session(url: "https://checkout.stripe.com/c/pay/cs_test_xyz")

    sign_in @user
    post account_subscription_url, params: { plan: :basic }

    assert_redirected_to "https://checkout.stripe.com/c/pay/cs_test_xyz"
  end

  test "create flashes a friendly error when the plan id is missing" do
    setup_billing(@user)
    sign_in @user

    post account_subscription_url, params: { plan: :gold } # not basic/pro
    assert_redirected_to new_account_subscription_url
    assert_match(/Pick Basic or Pro/i, flash[:alert])
  end

  test "create flashes when Stripe returns a card error" do
    setup_billing(@user)
    stub_stripe_error(method: :post, path: "/v1/checkout/sessions")

    sign_in @user
    post account_subscription_url, params: { plan: :basic }

    assert_redirected_to new_account_subscription_url
    assert_match(/Stripe error/i, flash[:alert])
  end

  # --- create (plan swap) -- THE c52d672 regression ------------------------

  test "PATCH-equivalent: an existing active sub is updated in place, not duplicated" do
    customer = setup_billing(@user, plan: :basic)
    existing = customer.subscription

    stub_stripe_subscription_retrieve(id: existing.processor_id, price_id: ENV["PAY_STRIPE_PLAN_BASIC"])
    stub_stripe_subscription_update(id: existing.processor_id, new_price_id: ENV["PAY_STRIPE_PLAN_PRO"])

    sign_in @user

    assert_no_difference -> { Pay::Subscription.where(customer_id: customer.id).count } do
      post account_subscription_url, params: { plan: :pro }
    end

    assert_redirected_to account_subscription_url
    assert_match(/Plan updated/i, flash[:notice])
  end

  # --- embedded ------------------------------------------------------------

  test "embedded renders with a client_secret and the public Stripe key" do
    setup_billing(@user)
    stub_stripe_subscription_create(client_secret_shape: :basil)

    ENV["STRIPE_PUBLIC_KEY"] = "pk_test_visible"
    sign_in @user
    post embedded_account_subscription_url, params: { plan: :basic }

    assert_response :success
    assert_select "[data-stripe-elements-client-secret-value='pi_test_1_secret_basil']"
    assert_select "[data-stripe-elements-publishable-key-value='pk_test_visible']"
  end

  test "embedded swaps inline when the user already has an active sub" do
    customer = setup_billing(@user, plan: :basic)
    existing = customer.subscription
    stub_stripe_subscription_retrieve(id: existing.processor_id, price_id: ENV["PAY_STRIPE_PLAN_BASIC"])
    stub_stripe_subscription_update(id: existing.processor_id, new_price_id: ENV["PAY_STRIPE_PLAN_PRO"])

    sign_in @user
    post embedded_account_subscription_url, params: { plan: :pro }

    assert_redirected_to account_subscription_url
    assert_match(/Plan updated/i, flash[:notice])
  end

  test "embedded surfaces Stripe errors as a flash and redirect" do
    setup_billing(@user)
    stub_stripe_error(method: :post, path: "/v1/subscriptions")

    sign_in @user
    post embedded_account_subscription_url, params: { plan: :basic }
    assert_redirected_to new_account_subscription_url
    assert_match(/Stripe error/i, flash[:alert])
  end

  # --- show ----------------------------------------------------------------

  test "show renders for the user's own sub" do
    setup_billing(@user, plan: :basic)
    sign_in @user
    get account_subscription_url
    assert_response :success
    assert_select "h1", /Subscription/i
  end

  test "show renders the empty state when the user has no sub" do
    sign_in @user
    get account_subscription_url
    assert_response :success
    assert_match(/don't have an active subscription/i, response.body)
  end

  # --- destroy -------------------------------------------------------------

  test "destroy redirects with an alert when there is no active sub" do
    setup_billing(@user)
    sign_in @user
    delete account_subscription_url
    assert_redirected_to account_subscription_url
    assert_match(/No active subscription/i, flash[:alert])
  end

  test "destroy cancels via Pay when the user owns an active sub" do
    customer = setup_billing(@user, plan: :basic)
    existing = customer.subscription
    stub_stripe_subscription_cancel(id: existing.processor_id)

    sign_in @user
    delete account_subscription_url
    assert_redirected_to account_subscription_url
  end

  test "destroy surfaces a Stripe error from cancel as a friendly flash" do
    customer = setup_billing(@user, plan: :basic)
    existing = customer.subscription
    stub_stripe_error(method: :post, path: "/v1/subscriptions/#{existing.processor_id}")

    sign_in @user
    delete account_subscription_url

    assert_redirected_to account_subscription_url
    assert_match(/Couldn't cancel/i, flash[:alert])
  end

  # --- billing_portal ------------------------------------------------------

  test "billing_portal redirects to the Stripe portal url" do
    setup_billing(@user, plan: :basic)
    stub_stripe_billing_portal_session(url: "https://billing.stripe.com/p/session/owner")

    sign_in @user
    post billing_portal_account_subscription_url
    assert_redirected_to "https://billing.stripe.com/p/session/owner"
  end

  test "billing_portal surfaces Stripe errors with a flash" do
    setup_billing(@user, plan: :basic)
    stub_stripe_error(method: :post, path: "/v1/billing_portal/sessions")

    sign_in @user
    post billing_portal_account_subscription_url
    assert_redirected_to account_subscription_url
    assert_match(/Couldn't open billing portal/i, flash[:alert])
  end

  # --- success / cancel ----------------------------------------------------

  test "success redirects back with a notice" do
    sign_in @user
    get success_account_subscription_url
    assert_redirected_to account_subscription_url
    assert_match(/being activated/i, flash[:notice])
  end

  test "cancel redirects back to the plan picker with an alert" do
    sign_in @user
    get cancel_account_subscription_url
    assert_redirected_to new_account_subscription_url
    assert_match(/wasn't completed/i, flash[:alert])
  end

  # --- auth boundary -------------------------------------------------------

  test "unauthenticated visitors are bounced to sign in" do
    get new_account_subscription_url
    assert_redirected_to new_user_session_url
  end

  # --- Pundit denial path (ApplicationController#user_not_authorized) -----
  #
  # No real route in this app can reach Pundit::NotAuthorizedError today (we
  # always pre-filter records by current_user). Force the policy's predicate
  # to false so the rescue handler runs end-to-end with a friendly flash and
  # redirect. The override is scoped to this test via ensure.
  test "Pundit denial routes through user_not_authorized with a friendly flash" do
    setup_billing(@user, plan: :basic)
    original = Pay::SubscriptionPolicy.instance_method(:show?)
    Pay::SubscriptionPolicy.define_method(:show?) { false }

    sign_in @user
    get account_subscription_url, headers: { "HTTP_REFERER" => root_url }

    assert_redirected_to root_url
    assert_match(/not authorized/i, flash[:alert])
  ensure
    Pay::SubscriptionPolicy.define_method(:show?, original) if original
  end
end
