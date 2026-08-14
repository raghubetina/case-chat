require "test_helper"

class CasePolicyTest < ActiveSupport::TestCase
  test "allows any authenticated user to create a case" do
    assert CasePolicy.new(create_user, Case).create?
    refute CasePolicy.new(nil, Case).create?
  end

  test "allows only the author to manage and inspect a case" do
    author = create_user
    other_user = create_user
    case_record = create_case(author:)

    author_policy = CasePolicy.new(author, case_record)
    other_policy = CasePolicy.new(other_user, case_record)

    %i[update? publish? archive? create_cohort? test_drive? inspect?].each do |query|
      assert author_policy.public_send(query), "expected the author to be allowed to #{query}"
      refute other_policy.public_send(query), "expected another user to be denied #{query}"
    end
  end

  test "allows an enrolled learner to view but not manage a case" do
    case_record = published_case
    learner = create_user(full_name: "Lee Learner")
    enroll(case_record:, user: learner)

    policy = CasePolicy.new(learner, case_record)

    assert policy.show?
    refute policy.update?
    refute CasePolicy.new(create_user, case_record).show?
  end

  test "scopes cases to authored and enrolled records" do
    user = create_user
    authored_case = create_case(author: user)
    enrolled_case = published_case
    enroll(case_record: enrolled_case, user:)
    create_case

    assert_equal [authored_case.id, enrolled_case.id].sort,
      CasePolicy::Scope.new(user, Case.all).resolve.pluck(:id).sort
    assert_empty CasePolicy::Scope.new(nil, Case.all).resolve
  end

  private

  def published_case(author: create_user)
    case_record = create_case(author:)
    create_stakeholder(case_record:)
    publish_case(case_record)
    case_record.reload
  end
end
