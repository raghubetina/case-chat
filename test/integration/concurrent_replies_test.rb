require "test_helper"
require_relative "../models/domain_test_helper"

# What happens when a student asks a second question before the contact has
# answered the first. Both halves of the transcript are involved: the bubble the
# answer streams into, and the history the answer is generated from.
class ConcurrentRepliesTest < ActionDispatch::IntegrationTest
  include DomainTestHelper

  setup do
    # register_user, not build_user: this test signs in for real.
    @student = register_user(full_name: "Jordan Lin")
    contact = build_contact
    contact.update!(in_starting_directory: true)
    contact.case_study.update!(published: true)
    enrollment = Enrollment.create!(user: @student, case_study: contact.case_study)
    @conversation = Conversation.create!(enrollment: enrollment, contact: contact)
    sign_in_as @student
  end

  def send_message(body)
    post thread_messages_path(@conversation),
      params: {message: {body: body}},
      headers: {"Accept" => "text/vnd.turbo-stream.html"}
    assert_response :success
    response.body
  end

  # Two replies in flight used to stream into one bubble: the pending markup was
  # keyed on the conversation, so the second send emitted a duplicate id.
  # getElementById returns the first match, so both contacts' deltas appended to
  # the same paragraph and one bubble was orphaned for the rest of the visit.
  test "each question gets a pending bubble of its own" do
    first = send_message("Why takeout at all?")
    second = send_message("And what does Marco say?")

    ids = (first + second).scan(/id="(pending_[a-z_]*message_[^"]+)"/).flatten.uniq
    bubbles = ids.grep(/\Apending_message_/)

    assert_equal 2, bubbles.size, "each send should target its own bubble, not reuse one id"
  end

  # The contact is one person holding one conversation. Generating two answers
  # at once means the second is written from a history that does not contain the
  # first, so the transcript reads as two people talking past each other.
  test "replies for one conversation are generated one at a time" do
    assert_equal 1, ContactReplyJob.concurrency_limit

    job = ContactReplyJob.new(@conversation.id, Message.new(id: "m1").id)
    other = ContactReplyJob.new(build_conversation.id, Message.new(id: "m2").id)

    assert_equal job.send(:concurrency_key), ContactReplyJob.new(@conversation.id, "m3").send(:concurrency_key),
      "two questions in the same thread must share a key so they queue behind each other"
    assert_not_equal job.send(:concurrency_key), other.send(:concurrency_key),
      "different threads must not block each other"
  end
end
