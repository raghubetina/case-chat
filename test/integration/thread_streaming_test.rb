require "test_helper"
require_relative "../models/domain_test_helper"

# A reply is rendered twice: into the pending bubble while it streams, then as a
# real message when it lands. The reader sees one bubble, so any difference
# between the two partials shows up as the text jumping at the end.
class ThreadStreamingTest < ActionDispatch::IntegrationTest
  include DomainTestHelper

  setup do
    @conversation = build_conversation
    @message = Message.create!(
      conversation: @conversation, body: "First line.\n\nSecond line.",
      sent_at: Time.current, from_contact: true
    )
  end

  # The classes that decide where the text sits. If these diverge the swap is
  # visible: gap-1 against gap-2 shifts the body 4px, and a missing
  # whitespace-pre-wrap collapses every paragraph break until the reply lands
  # and then springs it open several lines taller.
  # `grow` matters as much as the rest: without it the bubble column sizes to
  # its content, so the reply re-wraps on every frame as the column widens.
  LAYOUT = %w[gap-1 gap-2 grow max-w-prose whitespace-pre-wrap break-words text-base].freeze

  test "the streaming bubble lays text out exactly like the settled message" do
    assert_equal layout_classes(settled), layout_classes(streaming),
      "threads/_pending and threads/_message must agree, or the text moves when the reply completes"
  end

  test "a streamed paragraph break survives into the pending bubble" do
    assert_includes streaming, "whitespace-pre-wrap",
      "without this, multi-paragraph replies stream as one block and reflow at the end"
  end

  private

  def streaming
    ApplicationController.render(partial: "threads/pending", locals: {conversation: @conversation})
  end

  # from_contact, so the partial never reaches for current_user.
  def settled
    ApplicationController.render(
      partial: "threads/message",
      locals: {message: Message.includes(:introduced_contact, {conversation: :contact},
        {document_shares: :document}).find(@message.id), streaming: false}
    )
  end

  def layout_classes(html)
    LAYOUT.select { |name| html.match?(/\b#{Regexp.escape(name)}\b/) }
  end
end
