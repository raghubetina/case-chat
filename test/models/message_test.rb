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

  should belong_to(:conversation)
  should have_many(:introductions).class_name("Introduction").dependent(:nullify)
  should have_many(:document_shares).dependent(:destroy)

  should validate_presence_of(:sent_at)

  # A contact may answer with a file and no words, so an empty body is only an
  # error on the student's side of the conversation.
  test "requires a body from the student but not from a contact" do
    conversation = build_conversation

    student_said_nothing = Message.new(conversation:, sent_at: Time.current, from_contact: false)
    contact_sent_a_file = Message.new(conversation:, sent_at: Time.current, from_contact: true)

    assert_not student_said_nothing.valid?
    assert student_said_nothing.errors.of_kind?(:body, :blank)
    assert contact_sent_a_file.valid?
  end

  test "rejects a message that does not say who spoke" do
    message = Message.new(conversation: build_conversation, body: "Hi", sent_at: Time.current)

    assert_not message.valid?
    assert message.errors.of_kind?(:from_contact, :inclusion)
  end
end
