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
#  cache_read_price   :decimal(12, 6)
#  cache_read_tokens  :integer          default(0), not null
#  cache_write_price  :decimal(12, 6)
#  cache_write_tokens :integer          default(0), not null
#  duration_ms        :integer
#  effort             :string
#  input_price        :decimal(12, 6)
#  input_tokens       :integer          default(0), not null
#  model              :string           not null
#  output_price       :decimal(12, 6)
#  output_tokens      :integer          default(0), not null
#  provider           :string           not null
#  raw                :jsonb
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  contact_id         :uuid             not null
#  message_id         :uuid
#  test_drive_id      :uuid
#
# Indexes
#
#  index_model_calls_on_contact_id            (contact_id)
#  index_model_calls_on_message_id            (message_id)
#  index_model_calls_on_model_and_created_at  (model,created_at)
#  index_model_calls_on_test_drive_id         (test_drive_id)
#
# Foreign Keys
#
#  fk_rails_...  (contact_id => contacts.id) ON DELETE => cascade
#  fk_rails_...  (message_id => messages.id) ON DELETE => nullify
#  fk_rails_...  (test_drive_id => test_drives.id) ON DELETE => nullify
#
class ModelCall < ApplicationRecord
  belongs_to :contact, class_name: "Contact", optional: false
  belongs_to :message, class_name: "Message", optional: true
  # Present on a rehearsal, absent on a student's reply. A call with neither
  # is a rehearsal from before drives were kept.
  belongs_to :test_drive, class_name: "TestDrive", optional: true

  validates :provider, presence: true
  validates :model, presence: true
  # A provider that reports no usage field at all leaves these nil, which the
  # NOT NULL columns would reject at the database instead of here.
  validates :input_tokens, :output_tokens, :cache_read_tokens, :cache_write_tokens, presence: true

  scope :newest_first, -> { order(created_at: :desc) }

  # Dollars, from the rate this call was billed at rather than today's rate.
  # nil when no rate was stored, which is every call made before rates were
  # recorded and any call on a model the catalogue did not know.
  def cost
    self.class.price(
      input_tokens: input_tokens, output_tokens: output_tokens,
      cache_read_tokens: cache_read_tokens,
      input_price: input_price, output_price: output_price, cache_read_price: cache_read_price
    )
  end

  def priced? = !cost.nil?

  # Cached reads bill at their own lower rate, so they come out of input rather
  # than adding to it. Cache writes are recorded but not billed here: both
  # providers charge 1.25x input for them, so every total reads low.
  def self.price(input_tokens:, output_tokens:, cache_read_tokens: 0,
    input_price: nil, output_price: nil, cache_read_price: nil)
    return nil if input_price.nil? || output_price.nil?

    fresh_input = [input_tokens - cache_read_tokens, 0].max
    cached = cache_read_price.nil? ? 0 : cache_read_tokens * cache_read_price.to_f

    (fresh_input * input_price.to_f + cached + output_tokens * output_price.to_f) / 1_000_000.0
  end

  # What the briefing cache actually bought on this call.
  def cache_hit_rate
    return 0.0 if input_tokens.zero?

    cache_read_tokens.to_f / input_tokens
  end

  # The rate is looked up now and written down, because it is a fact about this
  # request. Derived later from whatever the catalogue happens to say, a
  # correction to one number would silently re-price every call ever made.
  def self.record(contact:, reply:, model:, provider:, effort: nil, message: nil, test_drive: nil, duration_ms: nil)
    usage = reply.usage
    entry = ModelCatalogue.find(model)

    create!(
      contact: contact, message: message, test_drive: test_drive,
      provider: provider, model: model, effort: effort,
      input_tokens: usage.input_tokens, output_tokens: usage.output_tokens,
      cache_read_tokens: usage.cache_read_tokens, cache_write_tokens: usage.cache_write_tokens,
      input_price: entry&.input_price, output_price: entry&.output_price,
      cache_read_price: entry&.cache_read_price, cache_write_price: entry&.cache_write_price,
      duration_ms: duration_ms, raw: reply.raw
    )
  end
end
