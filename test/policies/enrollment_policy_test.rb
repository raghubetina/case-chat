require "test_helper"

class EnrollmentPolicyTest < ActiveSupport::TestCase
  test "allows a learner to join only themselves to a published case" do
    learner = create_user(full_name: "Lee Learner")
    published_cohort = create_cohort(case_record: published_case)
    enrollment = Enrollment.new(user: learner, cohort: published_cohort)

    assert EnrollmentPolicy.new(learner, enrollment).create?
    refute EnrollmentPolicy.new(create_user, enrollment).create?

    draft_enrollment = Enrollment.new(user: learner, cohort: create_cohort(case_record: create_case))
    refute EnrollmentPolicy.new(learner, draft_enrollment).create?
    refute EnrollmentPolicy.new(nil, enrollment).create?
  end

  test "keeps learner actions separate from author inspection" do
    author = create_user
    case_record = published_case(author:)
    learner = create_user(full_name: "Lee Learner")
    enrollment = Enrollment.create!(user: learner, cohort: create_cohort(case_record:))

    learner_policy = EnrollmentPolicy.new(learner, enrollment)
    author_policy = EnrollmentPolicy.new(author, enrollment)

    assert learner_policy.show?
    assert learner_policy.learn?
    assert learner_policy.reset?
    refute learner_policy.inspect?

    assert author_policy.show?
    assert author_policy.inspect?
    refute author_policy.learn?
    refute author_policy.reset?
  end

  test "denies an unrelated user access to an enrollment" do
    enrollment = Enrollment.create!(
      user: create_user(full_name: "Lee Learner"),
      cohort: create_cohort(case_record: published_case)
    )
    policy = EnrollmentPolicy.new(create_user, enrollment)

    refute policy.show?
    refute policy.learn?
    refute policy.reset?
    refute policy.inspect?
  end

  test "scopes enrollments to learner ownership and authored cases" do
    user = create_user
    own_enrollment = Enrollment.create!(
      user:,
      cohort: create_cohort(case_record: published_case)
    )
    authored_enrollment = Enrollment.create!(
      user: create_user,
      cohort: create_cohort(case_record: published_case(author: user))
    )
    Enrollment.create!(
      user: create_user,
      cohort: create_cohort(case_record: published_case)
    )

    assert_equal [own_enrollment.id, authored_enrollment.id].sort,
      EnrollmentPolicy::Scope.new(user, Enrollment.all).resolve.pluck(:id).sort
    assert_empty EnrollmentPolicy::Scope.new(nil, Enrollment.all).resolve
  end

  private

  def create_cohort(case_record:)
    Cohort.create!(
      case: case_record,
      name: "Fall pilot",
      join_code: "JOIN-#{SecureRandom.hex(4)}"
    )
  end

  def published_case(author: create_user)
    case_record = create_case(author:)
    create_stakeholder(case_record:)
    publish_case(case_record)
    case_record.reload
  end
end
