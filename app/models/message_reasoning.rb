# What the provider actually produced for one assistant turn, kept so the next
# turn can hand it back.
#
# Anthropic calls this the content array and will not remember it for us:
# thinking blocks come back carrying a signature, and passing them unmodified
# is the only way a person keeps reasoning from one question to the next. On
# Claude Opus 5 the thinking text is omitted and the signature is the whole
# payload, so a block that looks empty is the thing worth keeping.
#
# OpenAI calls it the output array. Same idea, echoed back in the next input.
class MessageReasoning < ApplicationRecord
  belongs_to :message, class_name: "Message", optional: false

  validates :provider, presence: true
  validates :model, presence: true
  # An empty array would be a row claiming to hold a turn and holding nothing,
  # which the next turn would replay as an empty assistant message. The caller
  # skips writing a row at all when there is nothing to keep.
  validates :blocks, presence: true

  # SDK response objects carry bookkeeping the API will not accept back --
  # streaming buffers and a reference to the client that built them. What goes
  # over the wire has to be the block the provider described, and nothing else.
  INTERNAL = /\A_|\Acaller_/

  def self.clean(blocks)
    Array(blocks).map { |block| scrub(block) }
  end

  def self.scrub(value)
    case value
    when Hash
      value.reject { |key, _| key.to_s.match?(INTERNAL) }
        .transform_values { |nested| scrub(nested) }
    when Array then value.map { |nested| scrub(nested) }
    else value
    end
  end
end
