require "test_helper"

class HomeControllerTest < ActionDispatch::IntegrationTest
  test "unauthenticated visitors are redirected to sign in" do
    get root_url
    assert_redirected_to new_user_session_url
  end

  test "signed-in user sees the dashboard" do
    sign_in users(:basic_user)
    get root_url
    assert_response :success
    assert_select "h1", "Welcome"
  end
end
