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
# == Schema Information
#
# Table name: message_reasonings
#
#  id          :uuid             not null, primary key
#  blocks      :jsonb            not null
#  model       :string           not null
#  provider    :string           not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  message_id  :uuid             not null
#  response_id :string
#
# Indexes
#
#  index_message_reasonings_on_message_id  (message_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (message_id => messages.id) ON DELETE => cascade
#
class MessageReasoning < ApplicationRecord
  belongs_to :message, class_name: "Message", optional: false

  validates :provider, presence: true
  validates :model, presence: true
  # A row has to carry something the next turn can use. Anthropic supplies
  # blocks to echo; OpenAI supplies an id for state it kept itself. A row with
  # neither is one the next turn would read and learn nothing from.
  validate :carries_something

  def carries_something
    return if blocks.present? || response_id.present?

    errors.add(:base, "a reasoning row must carry blocks or a response id")
  end

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
