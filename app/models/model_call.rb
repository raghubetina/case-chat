# One request to a provider, kept so token use — and therefore cost — can be
# tabulated after the fact instead of estimated.
#
# The whole response body is retained in `raw`. Usage shapes differ per provider
# and change without notice, so a column nobody thought to add is a number that
# cannot be recovered; re-running a month of replies to get it back is not an
# option. It is also where a response id would be found, which is the handle
# server-side conversation state would need.
# == Schema Information
#
# Table name: model_calls
#
#  id                 :uuid             not null, primary key
#  cache_read_tokens  :integer          default(0), not null
#  cache_write_tokens :integer          default(0), not null
#  duration_ms        :integer
#  effort             :string
#  input_tokens       :integer          default(0), not null
#  model              :string           not null
#  output_tokens      :integer          default(0), not null
#  provider           :string           not null
#  raw                :jsonb
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  contact_id         :uuid             not null
#  message_id         :uuid
#
# Indexes
#
#  index_model_calls_on_contact_id            (contact_id)
#  index_model_calls_on_message_id            (message_id)
#  index_model_calls_on_model_and_created_at  (model,created_at)
#
# Foreign Keys
#
#  fk_rails_...  (contact_id => contacts.id) ON DELETE => cascade
#  fk_rails_...  (message_id => messages.id) ON DELETE => nullify
#
class ModelCall < ApplicationRecord
  belongs_to :contact, class_name: "Contact", optional: false
  belongs_to :message, class_name: "Message", optional: true

  validates :provider, presence: true
  validates :model, presence: true
  # A provider that reports no usage field at all leaves these nil, which the
  # NOT NULL columns would reject at the database instead of here.
  validates :input_tokens, :output_tokens, :cache_read_tokens, :cache_write_tokens, presence: true

  scope :newest_first, -> { order(created_at: :desc) }

  # Dollars, or nil when the model's price is not known. A blank total is a
  # prompt to go and find the rate; an invented one is a wrong answer that
  # looks right.
  def cost
    ModelCatalogue.cost(
      model: model,
      input_tokens: input_tokens,
      output_tokens: output_tokens,
      cache_read_tokens: cache_read_tokens
    )
  end

  # What the briefing cache actually bought on this call.
  def cache_hit_rate
    return 0.0 if input_tokens.zero?

    cache_read_tokens.to_f / input_tokens
  end

  def self.record(contact:, reply:, model:, provider:, effort: nil, message: nil, duration_ms: nil)
    usage = reply.usage

    create!(
      contact: contact, message: message,
      provider: provider, model: model, effort: effort,
      input_tokens: usage.input_tokens, output_tokens: usage.output_tokens,
      cache_read_tokens: usage.cache_read_tokens, cache_write_tokens: usage.cache_write_tokens,
      duration_ms: duration_ms, raw: reply.raw
    )
  end
end
