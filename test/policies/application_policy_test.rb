require "test_helper"

class ApplicationPolicyTest < ActiveSupport::TestCase
  setup do
    @user = users(:basic_user)
  end

  # --- default-deny --------------------------------------------------------

  test "every CRUD predicate is false by default" do
    policy = ApplicationPolicy.new(@user, Object.new)
    refute policy.index?
    refute policy.show?
    refute policy.create?
    refute policy.new?
    refute policy.update?
    refute policy.edit?
    refute policy.destroy?
  end

  # --- owned? shapes -------------------------------------------------------

  test "owned? walks record.user for bare AR-shaped records" do
    fake = Struct.new(:user).new(@user)
    policy = ApplicationPolicy.new(@user, fake)
    assert policy.send(:owned?)
  end

  test "owned? returns false when the bare-AR owner is someone else" do
    fake = Struct.new(:user).new(users(:pro_user))
    policy = ApplicationPolicy.new(@user, fake)
    refute policy.send(:owned?)
  end

  test "owned? returns false for class records (ownership N/A)" do
    policy = ApplicationPolicy.new(@user, Pay::Subscription)
    refute policy.send(:owned?)
  end

  test "owned? returns false for anonymous users" do
    fake = Struct.new(:user).new(@user)
    policy = ApplicationPolicy.new(nil, fake)
    refute policy.send(:owned?)
  end

  # --- Scope ---------------------------------------------------------------

  test "Scope#resolve raises -- subclasses must implement it" do
    assert_raises(NoMethodError) do
      ApplicationPolicy::Scope.new(@user, Pay::Subscription).resolve
    end
  end
end
