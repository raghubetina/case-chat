require "test_helper"

class ApplicationPolicyTest < ActiveSupport::TestCase
  test "denies every standard action by default" do
    policy = ApplicationPolicy.new(nil, create_case)

    %i[index? show? create? new? update? edit? destroy?].each do |query|
      refute policy.public_send(query), "expected #{query} to be denied"
    end
  end

  test "resolves the default scope to no records" do
    create_case

    assert_empty ApplicationPolicy::Scope.new(nil, Case.all).resolve
  end
end
