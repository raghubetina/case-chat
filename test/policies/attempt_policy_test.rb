require "test_helper"

class AttemptPolicyTest < ActiveSupport::TestCase
  test "allows a learner to use only their current open attempt" do
    learner = create_user(full_name: "Lee Learner")
    case_record = published_case
    first_attempt = start_attempt(case_record:, user: learner)
    second_attempt = Attempts::Reset.call(enrollment: Enrollment.find(first_attempt.enrollment_id))

    refute AttemptPolicy.new(learner, first_attempt).show?
    refute AttemptPolicy.new(learner, first_attempt).learn?
    assert AttemptPolicy.new(learner, second_attempt).show?
    assert AttemptPolicy.new(learner, second_attempt).learn?
    refute AttemptPolicy.new(learner, second_attempt).inspect?
  end

  test "allows a case author to inspect but not act as the learner" do
    author = create_user
    case_record = published_case(author:)
    attempt = start_attempt(case_record:)
    policy = AttemptPolicy.new(author, attempt)

    assert policy.show?
    assert policy.inspect?
    refute policy.learn?
  end

  test "denies an unrelated user access to an attempt" do
    attempt = start_attempt(case_record: published_case)
    policy = AttemptPolicy.new(create_user, attempt)

    refute policy.show?
    refute policy.learn?
    refute policy.inspect?
  end

  test "scopes a learner to their current open attempts" do
    learner = create_user(full_name: "Lee Learner")
    case_record = published_case
    closed_attempt = start_attempt(case_record:, user: learner)
    open_attempt = Attempts::Reset.call(enrollment: Enrollment.find(closed_attempt.enrollment_id))
    start_attempt(case_record: published_case)

    assert_equal [open_attempt.id], AttemptPolicy::Scope.new(learner, Attempt.all).resolve.pluck(:id)
    assert_empty AttemptPolicy::Scope.new(nil, Attempt.all).resolve
  end

  test "scopes a case author to all learner attempts" do
    author = create_user
    case_record = published_case(author:)
    closed_attempt = start_attempt(case_record:)
    open_attempt = Attempts::Reset.call(enrollment: Enrollment.find(closed_attempt.enrollment_id))
    start_attempt(case_record: published_case)

    assert_equal [closed_attempt.id, open_attempt.id].sort,
      AttemptPolicy::Scope.new(author, Attempt.all).resolve.pluck(:id).sort
  end

  private

  def published_case(author: create_user)
    case_record = create_case(author:)
    create_stakeholder(case_record:)
    publish_case(case_record)
    case_record.reload
  end
end
