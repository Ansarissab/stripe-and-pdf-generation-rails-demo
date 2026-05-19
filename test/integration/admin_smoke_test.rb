require "test_helper"

# Smoke-tests every ActiveAdmin page reaches a 200 (or expected redirect)
# for a signed-in AdminUser. The point is not coverage of the AA DSL --
# `app/admin/*.rb` is SimpleCov-filtered -- but catching the Ransack-style
# runtime errors AA loves to throw when the underlying model is missing
# allowlists, attribute references, or association wiring. One request per
# page is enough: if AA can render the index it has resolved menu/auth/ransack.
class AdminSmokeTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @admin = admin_users(:admin)
    # Real POST against the admin login endpoint -- the IntegrationHelpers
    # sign_in helper occasionally trips over Warden state when multiple
    # Devise scopes (User + AdminUser) share the same Rails session, so going
    # through the actual sign-in flow is the most reliable smoke test.
    post new_admin_user_session_path, params: {
      admin_user: { email: @admin.email, password: "password" }
    }

    # Seed enough Pay data so AA's index queries have something to render.
    user     = users(:basic_user)
    @customer = setup_billing(user, plan: :basic)
    @subscription = @customer.subscription
    @charge  = make_charge(@customer, subscription: @subscription)
  end

  test "GET /admin (dashboard) renders" do
    get "/admin"
    assert_response :success
  end

  test "GET /admin/users renders" do
    get "/admin/users"
    assert_response :success
  end

  test "GET /admin/users/:id renders" do
    get "/admin/users/#{users(:basic_user).id}"
    assert_response :success
  end

  test "GET /admin/pay_customers renders" do
    get "/admin/pay_customers"
    assert_response :success
  end

  test "GET /admin/pay_customers/:id renders" do
    get "/admin/pay_customers/#{@customer.id}"
    assert_response :success
  end

  test "GET /admin/pay_subscriptions renders" do
    get "/admin/pay_subscriptions"
    assert_response :success
  end

  test "GET /admin/pay_subscriptions/:id renders" do
    get "/admin/pay_subscriptions/#{@subscription.id}"
    assert_response :success
  end

  test "GET /admin/pay_charges renders" do
    get "/admin/pay_charges"
    assert_response :success
  end

  test "GET /admin/pay_charges/:id renders" do
    get "/admin/pay_charges/#{@charge.id}"
    assert_response :success
  end

  test "GET /admin/admin_users renders" do
    get "/admin/admin_users"
    assert_response :success
  end

  test "GET /admin/admin_users/:id renders" do
    get "/admin/admin_users/#{@admin.id}"
    assert_response :success
  end

  test "unauthenticated /admin redirects to admin login" do
    sign_out @admin
    get "/admin"
    assert_redirected_to new_admin_user_session_path
  end
end
