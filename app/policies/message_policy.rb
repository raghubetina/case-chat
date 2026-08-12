class MessagePolicy < ApplicationPolicy
  def index? = signed_in?

  def show? = allowed_to?(:show?, record.conversation)

  def new? = signed_in?

  def create? = Conversation.where(id: record.conversation_id)
    .merge(authorized_scope(Conversation.all, as: :default)).exists?

  # Transcripts are the record of what happened; nobody edits one after the fact.
  def update? = false

  def destroy? = author_of?(record.conversation.contact.case_study)

  relation_scope do |relation|
    next relation.none unless signed_in?

    relation.where(conversation_id: authorized_scope(Conversation.all, as: :default).select(:id))
  end
end
