class UserPolicy < ApplicationPolicy
  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.none unless user

      scope.where(id: user.id)
    end
  end

  def show?
    owns_record?
  end

  def update?
    owns_record?
  end

  private

  def owns_record?
    authenticated? && record.id == user.id
  end
end
