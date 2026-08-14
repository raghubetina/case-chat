require "test_helper"

class StakeholderPolicyTest < ActiveSupport::TestCase
  test "allows only the case author to create and update stakeholders" do
    author = create_user
    case_record = create_case(author:)
    stakeholder = create_stakeholder(case_record:)
    candidate = case_record.stakeholders.build

    %i[create? update?].each do |query|
      record = (query == :create?) ? candidate : stakeholder

      assert StakeholderPolicy.new(author, record).public_send(query)
      refute StakeholderPolicy.new(create_user, record).public_send(query)
      refute StakeholderPolicy.new(nil, record).public_send(query)
    end
  end

  test "scopes stakeholders to cases authored by the user" do
    author = create_user
    own_case = create_case(author:)
    own_stakeholder = create_stakeholder(case_record: own_case)
    enrolled_case = create_case
    enrolled_stakeholder = create_stakeholder(case_record: enrolled_case)
    enroll(case_record: enrolled_case, user: author)
    foreign_stakeholder = create_stakeholder(case_record: create_case)

    assert_equal [own_stakeholder.id],
      StakeholderPolicy::Scope.new(author, Stakeholder.all).resolve.pluck(:id)
    assert_empty StakeholderPolicy::Scope.new(nil, Stakeholder.all).resolve
    refute_includes StakeholderPolicy::Scope.new(author, Stakeholder.all).resolve, enrolled_stakeholder
    refute_includes StakeholderPolicy::Scope.new(author, Stakeholder.all).resolve, foreign_stakeholder
  end
end
