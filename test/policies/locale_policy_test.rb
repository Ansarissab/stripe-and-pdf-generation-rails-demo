require "test_helper"

class LocalePolicyTest < ActiveSupport::TestCase
  setup do
    @user = users(:basic_user)
  end

  test "signed-in users may flip the locale" do
    policy = LocalePolicy.new(@user, :locale)
    assert policy.update?
  end

  test "anonymous visitors are denied" do
    policy = LocalePolicy.new(nil, :locale)
    refute policy.update?
  end
end
