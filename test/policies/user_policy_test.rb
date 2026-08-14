require "test_helper"

class UserPolicyTest < ActiveSupport::TestCase
  test "allows a user to view and update only their own account" do
    user = create_user
    other_user = create_user

    assert UserPolicy.new(user, user).show?
    assert UserPolicy.new(user, user).update?
    refute UserPolicy.new(user, other_user).show?
    refute UserPolicy.new(user, other_user).update?
    refute UserPolicy.new(nil, user).show?
  end

  test "scopes accounts to the current user" do
    user = create_user
    create_user

    assert_equal [user.id], UserPolicy::Scope.new(user, User.all).resolve.pluck(:id)
    assert_empty UserPolicy::Scope.new(nil, User.all).resolve
  end
end
