class TestDrivePolicy < ApplicationPolicy
  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.none unless user

      scope.where(author_id: user.id)
    end
  end

  def show?
    author?
  end

  def create?
    return false unless author?

    stakeholder_ids = Stakeholder.where(
      case_id: Case.where(author_id: user.id).select(:id)
    ).select(:id)
    Stakeholder.where(id: record.stakeholder_id)
      .where(id: stakeholder_ids)
      .exists?
  end

  def reset?
    author?
  end

  def destroy?
    author?
  end

  private

  def author?
    authenticated? && record.author_id == user.id
  end
end
