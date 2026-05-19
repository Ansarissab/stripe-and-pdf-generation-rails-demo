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
    assert_respond_to users(:basic_user), :payment_processor
    assert_respond_to users(:basic_user), :pay_customers
  end

  test "ransackable_attributes excludes auth secrets and PII" do
    attrs = User.ransackable_attributes
    assert_includes attrs, "email"
    assert_includes attrs, "plan"
    %w[encrypted_password reset_password_token confirmation_token unlock_token current_sign_in_ip last_sign_in_ip unconfirmed_email].each do |sensitive|
      assert_not_includes attrs, sensitive, "#{sensitive} must NOT be searchable in admin"
    end
  end

  test "ransackable_associations only exposes pay_customers" do
    assert_equal %w[pay_customers], User.ransackable_associations
  end
end
