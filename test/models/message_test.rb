require "test_helper"
require_relative "domain_test_helper"

# == Schema Information
#
# Table name: messages
#
#  id                    :uuid             not null, primary key
#  body                  :text             not null
#  from_contact          :boolean          not null
#  sent_at               :datetime         not null
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  conversation_id       :uuid             not null
#  introduced_contact_id :uuid
#
# Indexes
#
#  index_messages_on_conversation_id        (conversation_id)
#  index_messages_on_introduced_contact_id  (introduced_contact_id)
#
# Foreign Keys
#
#  fk_rails_...  (conversation_id => conversations.id) ON DELETE => cascade
#  fk_rails_...  (introduced_contact_id => contacts.id) ON DELETE => nullify
#
class MessageTest < ActiveSupport::TestCase
  include DomainTestHelper

  test "rejects a message without a body" do
    message = Message.new(conversation: build_conversation, sent_at: Time.current, from_contact: false)

    assert_not message.valid?
    assert message.errors.of_kind?(:body, :blank)
  end

  test "rejects a message that does not say who spoke" do
    message = Message.new(conversation: build_conversation, body: "Hi", sent_at: Time.current)

    assert_not message.valid?
    assert message.errors.of_kind?(:from_contact, :inclusion)
  end

  test "rejects attaching the same document twice to one message" do
    message = build_message
    document = build_document(case_study: message.conversation.contact.case_study)
    DocumentShare.create!(message: message, document: document)
    duplicate = DocumentShare.new(message: message, document: document)

    assert_not duplicate.valid?
    assert duplicate.errors.of_kind?(:document_id, :taken)
  end
end
