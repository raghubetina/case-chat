require "test_helper"

class CohortPolicyTest < ActiveSupport::TestCase
  test "allows only the case author to manage and inspect a cohort" do
    author = create_user
    case_record = create_case(author:)
    cohort = create_cohort(case_record:)
    other_user = create_user

    author_policy = CohortPolicy.new(author, cohort)
    other_policy = CohortPolicy.new(other_user, cohort)

    %i[show? create? update? destroy? inspect?].each do |query|
      assert author_policy.public_send(query), "expected the author to be allowed to #{query}"
      refute other_policy.public_send(query), "expected another user to be denied #{query}"
    end
  end

  test "allows a learner to view only a cohort they joined" do
    case_record = published_case
    learner = create_user(full_name: "Lee Learner")
    joined_cohort = create_cohort(case_record:)
    Enrollment.create!(user: learner, cohort: joined_cohort)
    other_cohort = create_cohort(case_record:, name: "Spring pilot")

    assert CohortPolicy.new(learner, joined_cohort).show?
    refute CohortPolicy.new(learner, other_cohort).show?
    refute CohortPolicy.new(learner, joined_cohort).update?
  end

  test "allows joining only a published case cohort" do
    user = create_user
    case_record = create_case
    cohort = create_cohort(case_record:)

    refute CohortPolicy.new(user, cohort).join?

    create_stakeholder(case_record:)
    publish_case(case_record)
    assert CohortPolicy.new(user, cohort).join?

    case_record.update!(status: "archived")
    refute CohortPolicy.new(user, cohort).join?
    refute CohortPolicy.new(nil, cohort).join?
  end

  test "scopes cohorts to authored and joined records" do
    user = create_user
    authored_cohort = create_cohort(case_record: create_case(author: user))
    joined_case = published_case
    joined_cohort = create_cohort(case_record: joined_case)
    Enrollment.create!(user:, cohort: joined_cohort)
    create_cohort(case_record: joined_case, name: "Not joined")

    assert_equal [authored_cohort.id, joined_cohort.id].sort,
      CohortPolicy::Scope.new(user, Cohort.all).resolve.pluck(:id).sort
    assert_empty CohortPolicy::Scope.new(nil, Cohort.all).resolve
  end

  private

  def create_cohort(case_record:, name: "Fall pilot")
    Cohort.create!(case: case_record, name:, join_code: "JOIN-#{SecureRandom.hex(4)}")
  end

  def published_case(author: create_user)
    case_record = create_case(author:)
    create_stakeholder(case_record:)
    publish_case(case_record)
    case_record.reload
  end
end
