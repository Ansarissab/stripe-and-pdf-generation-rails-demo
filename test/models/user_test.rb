require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "a new user has no plan until they subscribe" do
    user = User.new(email: "new@example.test")
    assert_nil user.plan
    assert_not user.basic?
    assert_not user.pro?
  end

  test "plan predicates map to the right tier" do
    assert users(:basic_user).basic?
    assert users(:pro_user).pro?
    assert_nil users(:unsubscribed_user).plan
  end

  test "email must be unique" do
    duplicate = User.new(email: users(:basic_user).email, password: "password")
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:email], "has already been taken"
  end

  test "pay_customer association is wired" do
    assert_respond_to users(:basic_user), :pay_customer
    assert_respond_to users(:basic_user), :payment_processor
  end
end
