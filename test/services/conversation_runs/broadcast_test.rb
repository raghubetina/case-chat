require "test_helper"

class ConversationRuns::BroadcastTest < ActiveSupport::TestCase
  test "replaces the persisted message on its conversation stream" do
    message = create_message
    calls = []
    fake_channel = Class.new do
      define_singleton_method(:broadcast_replace_to) do |*streamables, **rendering|
        calls << [streamables, rendering]
      end
    end

    stub_const(Turbo, :StreamsChannel, fake_channel) do
      ConversationRuns::Broadcast.call(message)
    end

    streamables, rendering = calls.fetch(0)
    assert_equal [message.conversation_id], streamables.map(&:id)
    assert_equal "message_#{message.id}", rendering.fetch(:target)
    assert_equal "messages/message", rendering.fetch(:partial)
    assert_equal message, rendering.fetch(:locals).fetch(:message)
  end

  test "renders pending and failed message states with escaped content" do
    pending_message = create_message
    pending_message.update!(status: "pending", content: "")
    pending_html = ApplicationController.render(
      partial: "messages/message",
      locals: {message: pending_message}
    )

    assert_includes pending_html, "id=\"message_#{pending_message.id}\""
    assert_includes pending_html, "data-message-status=\"pending\""
    assert_includes pending_html, "Thinking…"

    pending_message.update!(status: "failed", content: "<script>private()</script>")
    failed_html = ApplicationController.render(
      partial: "messages/message",
      locals: {message: pending_message}
    )

    assert_includes failed_html, "data-message-status=\"failed\""
    assert_includes failed_html, "&lt;script&gt;private()&lt;/script&gt;"
    refute_includes failed_html, "<script>private()</script>"
    assert_includes failed_html, "This reply stopped before it finished."
  end

  private

  def create_message
    author = create_user
    case_record = create_case(author:)
    stakeholder = create_stakeholder(case_record:)
    test_drive = TestDrives::Start.call(
      author:,
      stakeholder_id: stakeholder.id,
      left: {provider: "openai", model_id: "gpt-5-mini"}
    )
    conversation = Conversation.find_by!(test_drive_id: test_drive.id, slot: "left")
    Message.create!(
      conversation:,
      position: 1,
      role: "assistant",
      status: "streaming",
      content: "Partial"
    )
  end
end
