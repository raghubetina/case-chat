class CohortPolicy < ApplicationPolicy
  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.none unless user

      authored_case_ids = Case.where(author_id: user.id).select(:id)
      joined_cohort_ids = Enrollment.where(user_id: user.id).select(:cohort_id)

      scope.where(case_id: authored_case_ids).or(scope.where(id: joined_cohort_ids))
    end
  end

  def show?
    author? || enrolled?
  end

  def create?
    author?
  end

  def update?
    author?
  end

  def destroy?
    author?
  end

  def join?
    return false unless authenticated?

    Case.where(
      id: record.case_id,
      status: "published"
    ).where.not(published_configuration: nil).exists?
  end

  def inspect?
    author?
  end

  private

  def author?
    return false unless authenticated?

    Case.where(id: record.case_id, author_id: user.id).exists?
  end

  def enrolled?
    return false unless authenticated?

    Enrollment.where(cohort_id: record.id, user_id: user.id).exists?
  end
end
