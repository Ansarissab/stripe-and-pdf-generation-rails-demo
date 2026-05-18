require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "default plan is free" do
    user = User.new(email: "new@example.test")
    assert user.free?
  end

  test "plan predicates map to the right tier" do
    assert users(:free_user).free?
    assert users(:basic_user).basic?
    assert users(:pro_user).pro?
  end

  test "email must be unique" do
    duplicate = User.new(email: users(:free_user).email, password: "password")
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:email], "has already been taken"
  end

  test "pay_customer association is wired" do
    assert_respond_to users(:free_user), :pay_customer
    assert_respond_to users(:free_user), :payment_processor
  end
end
