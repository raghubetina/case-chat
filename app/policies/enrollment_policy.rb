class EnrollmentPolicy < ApplicationPolicy
  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.none unless user

      authored_cohort_ids = Cohort.where(
        case_id: Case.where(author_id: user.id).select(:id)
      ).select(:id)

      scope.where(user_id: user.id).or(scope.where(cohort_id: authored_cohort_ids))
    end
  end

  def show?
    learn? || inspect?
  end

  def create?
    return false unless learner_owns_record?

    published_case_ids = Case.where(status: "published")
      .where.not(published_configuration: nil)
      .select(:id)
    Cohort.where(id: record.cohort_id, case_id: published_case_ids).exists?
  end

  def learn?
    learner_owns_record?
  end

  def reset?
    learner_owns_record?
  end

  def inspect?
    return false unless authenticated?

    authored_case_ids = Case.where(author_id: user.id).select(:id)
    Cohort.where(id: record.cohort_id, case_id: authored_case_ids).exists?
  end

  private

  def learner_owns_record?
    authenticated? && record.user_id == user.id
  end
end
