class StakeholderPolicy < ApplicationPolicy
  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.none unless user

      scope.joins(:case).where(cases: {author_id: user.id})
    end
  end

  def create?
    author?
  end

  def update?
    author?
  end

  private

  def author?
    authenticated? && Case.where(id: record.case_id, author_id: user.id).exists?
  end
end
