class ConversationPolicy < ApplicationPolicy
  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.none unless user

      learner_attempt_ids = Attempt.where(
        enrollment_id: Enrollment.where(user_id: user.id).select(:id),
        ended_at: nil
      ).select(:id)
      authored_attempt_ids = Attempt.where(
        enrollment_id: Enrollment.where(
          cohort_id: Cohort.where(
            case_id: Case.where(author_id: user.id).select(:id)
          ).select(:id)
        ).select(:id)
      ).select(:id)
      owned_test_drive_ids = TestDrive.where(author_id: user.id).select(:id)

      scope.where(attempt_id: learner_attempt_ids)
        .or(scope.where(attempt_id: authored_attempt_ids))
        .or(scope.where(test_drive_id: owned_test_drive_ids))
    end
  end

  def show?
    send? || inspect?
  end

  def send?
    learner_owns_open_attempt? || author_owns_test_drive?
  end

  def inspect?
    return false unless authenticated? && record.attempt_id.present?

    authored_enrollment_ids = Enrollment.where(
      cohort_id: Cohort.where(
        case_id: Case.where(author_id: user.id).select(:id)
      ).select(:id)
    ).select(:id)
    Attempt.where(id: record.attempt_id, enrollment_id: authored_enrollment_ids).exists?
  end

  private

  def learner_owns_open_attempt?
    return false unless authenticated? && record.attempt_id.present?

    learner_enrollment_ids = Enrollment.where(user_id: user.id).select(:id)
    Attempt.where(
      id: record.attempt_id,
      enrollment_id: learner_enrollment_ids,
      ended_at: nil
    ).exists?
  end

  def author_owns_test_drive?
    return false unless authenticated? && record.test_drive_id.present?

    TestDrive.where(id: record.test_drive_id, author_id: user.id).exists?
  end
end
