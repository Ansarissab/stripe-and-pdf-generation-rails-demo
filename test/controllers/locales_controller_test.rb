require "test_helper"

class LocalesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:basic_user)
  end

  test "update stores a valid locale in the session and redirects back" do
    sign_in @user
    patch locale_url, params: { locale: :fr }, headers: { "HTTP_REFERER" => root_url }

    assert_redirected_to root_url
    assert_equal :fr, session[:locale]
  end

  test "update ignores an unknown locale" do
    sign_in @user
    patch locale_url, params: { locale: :xx }, headers: { "HTTP_REFERER" => root_url }

    assert_redirected_to root_url
    assert_nil session[:locale]
  end

  test "update bounces unauthenticated visitors to sign in" do
    patch locale_url, params: { locale: :fr }
    assert_redirected_to new_user_session_url
    assert_nil session[:locale]
  end
end
