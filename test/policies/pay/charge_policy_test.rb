require "test_helper"

class Pay::ChargePolicyTest < ActiveSupport::TestCase
  setup do
    @user         = users(:basic_user)
    @other        = users(:pro_user)
    @customer     = setup_billing(@user)
    @other_c      = setup_billing(@other)
    @charge       = make_charge(@customer)
    @other_charge = make_charge(@other_c, amount: 2900)
  end

  test "class-mode show? only requires sign-in (used by the index action)" do
    assert Pay::ChargePolicy.new(@user, Pay::Charge).show?
    refute Pay::ChargePolicy.new(nil,   Pay::Charge).show?
  end

  test "the owner may view their own charge" do
    assert Pay::ChargePolicy.new(@user, @charge).show?
  end

  test "another user is denied show on someone else's charge" do
    refute Pay::ChargePolicy.new(@user, @other_charge).show?
  end

  test "scope returns only the user's charges" do
    scope = Pay::ChargePolicy::Scope.new(@user, Pay::Charge).resolve
    assert_includes scope, @charge
    refute_includes scope, @other_charge
  end

  test "scope is empty for anonymous visitors" do
    assert_empty Pay::ChargePolicy::Scope.new(nil, Pay::Charge).resolve
  end
end
