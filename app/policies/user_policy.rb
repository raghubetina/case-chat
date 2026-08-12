class UserPolicy < ApplicationPolicy
  # Every signed-in user is visible by name to the people they share a case
  # with; the directory and cohort views depend on it.
  def index? = signed_in?

  def show? = signed_in?

  def new? = false

  def create? = false

  def update? = record.id == user&.id

  def destroy? = record.id == user&.id

  relation_scope do |relation|
    next relation.none unless signed_in?

    relation
  end
end
