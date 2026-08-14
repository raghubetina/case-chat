class AttemptPolicy < ApplicationPolicy
  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.none unless user

      learner_enrollment_ids = Enrollment.where(user_id: user.id).select(:id)
      authored_enrollment_ids = Enrollment.where(
        cohort_id: Cohort.where(
          case_id: Case.where(author_id: user.id).select(:id)
        ).select(:id)
      ).select(:id)

      scope.where(enrollment_id: learner_enrollment_ids, ended_at: nil)
        .or(scope.where(enrollment_id: authored_enrollment_ids))
    end
  end

  def show?
    learn? || inspect?
  end

  def learn?
    return false unless authenticated?

    learner_enrollment_ids = Enrollment.where(user_id: user.id).select(:id)
    Attempt.where(
      id: record.id,
      enrollment_id: learner_enrollment_ids,
      ended_at: nil
    ).exists?
  end

  def inspect?
    return false unless authenticated?

    authored_enrollment_ids = Enrollment.where(
      cohort_id: Cohort.where(
        case_id: Case.where(author_id: user.id).select(:id)
      ).select(:id)
    ).select(:id)
    Attempt.where(id: record.id, enrollment_id: authored_enrollment_ids).exists?
  end
end
