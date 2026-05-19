require "test_helper"

class HomePolicyTest < ActiveSupport::TestCase
  setup do
    @user = users(:basic_user)
  end

  test "signed-in users may access the dashboard" do
    policy = HomePolicy.new(@user, :home)
    assert policy.show?
    assert policy.index?
  end

  test "anonymous visitors are denied everything" do
    policy = HomePolicy.new(nil, :home)
    refute policy.show?
    refute policy.index?
    refute policy.create?
    refute policy.update?
    refute policy.destroy?
  end
end
