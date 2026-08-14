class CasePolicy < ApplicationPolicy
  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.none unless user

      enrolled_case_ids = Cohort.where(
        id: Enrollment.where(user_id: user.id).select(:cohort_id)
      ).select(:case_id)

      scope.where(author_id: user.id).or(scope.where(id: enrolled_case_ids))
    end
  end

  def show?
    author? || enrolled?
  end

  def create?
    authenticated?
  end

  def update?
    author?
  end

  def publish?
    author?
  end

  def archive?
    author?
  end

  def create_cohort?
    author?
  end

  def test_drive?
    author?
  end

  def inspect?
    author?
  end

  private

  def author?
    authenticated? && record.author_id == user.id
  end

  def enrolled?
    return false unless authenticated?

    Enrollment.where(
      user_id: user.id,
      cohort_id: Cohort.where(case_id: record.id).select(:id)
    ).exists?
  end
end
