require "test_helper"

# What actually goes over the wire for one streamed fragment.
#
# The fragment used to be a partial, and every ERB file ends with a newline, so
# each chunk arrived as "<chunk>\n". The paragraph it streams into is
# whitespace-pre-wrap, so those newlines rendered as hard line breaks: a reply
# came in as a jagged column, one flush per line, then reflowed into prose the
# moment the finished message replaced it. Every word moved.
class StreamedDeltaTest < ActiveSupport::TestCase
  include ActionCable::TestHelper

  STREAM = "streamed-delta-test"

  # The real broadcast path, not a reconstruction of it: turbo-rails decides
  # how `content:` reaches the wire, and that decision is the thing under test.
  def stream_one(text)
    Turbo::StreamsChannel.broadcast_append_to(
      STREAM, target: "body", content: ERB::Util.html_escape(text)
    )
    ActiveSupport::JSON.decode(broadcasts(STREAM).last)
  end

  test "a streamed fragment carries no trailing newline" do
    payload = stream_one("Same shortage,")

    assert_includes payload, "<template>Same shortage,</template>",
      "a newline here renders as a hard line break under whitespace-pre-wrap"
    assert_no_match(/\n<\/template>/, payload)
  end

  # The newline the model actually wrote still has to survive: replies have
  # paragraph breaks in them, which is why the paragraph is pre-wrap at all.
  test "a newline the model wrote is preserved" do
    assert_includes stream_one("One.\n\nTwo."), "One.\n\nTwo."
  end

  # turbo-rails inserts `content:` raw — tag.template(content.to_s.html_safe) —
  # so nothing but this escaping stands between model output and the document.
  test "markup in a fragment is escaped rather than inserted" do
    payload = stream_one("<script>alert(1)</script>")

    assert_no_match(/<script>/, payload)
    assert_includes payload, "&lt;script&gt;"
  end
end
