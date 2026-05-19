require "test_helper"

class Account::InvoicesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user      = users(:basic_user)
    @other     = users(:pro_user)
    @customer  = setup_billing(@user)
    @other_cus = setup_billing(@other)
    @charge    = make_charge(@customer)
  end

  test "redirects when unauthenticated" do
    get account_invoices_url
    assert_redirected_to new_user_session_url
  end

  test "lists only the current user's charges" do
    make_charge(@other_cus, amount: 2900)

    sign_in @user
    get account_invoices_url
    assert_response :success
    assert_select "td", text: /9\.00/
    assert_select "td", text: /29\.00/, count: 0
  end

  test "streams a PDF for the user's own charge" do
    sign_in @user
    get account_invoice_url(@charge)
    assert_response :success
    assert_equal "application/pdf", response.media_type
    assert response.body.start_with?("%PDF"), "expected response to be a PDF"
  end

  test "redirects with a friendly message when accessing another user's invoice" do
    other_charge = make_charge(@other_cus, amount: 2900)

    sign_in @user
    get account_invoice_url(other_charge)
    assert_redirected_to account_invoices_url
    assert_match(/not found/i, flash[:alert])
  end
end
