class DocumentSharePolicy < ApplicationPolicy
  def index? = signed_in?

  def show? = allowed_to?(:show?, record.message)

  def new? = signed_in?

  def create? = Message.where(id: record.message_id)
    .merge(authorized_scope(Message.all, as: :default)).exists?

  def update? = false

  def destroy? = allowed_to?(:destroy?, record.message)

  relation_scope do |relation|
    next relation.none unless signed_in?

    relation.where(message_id: authorized_scope(Message.all, as: :default).select(:id))
  end
end
