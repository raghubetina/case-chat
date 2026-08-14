# == Schema Information
#
# Table name: model_runs
#
#  id                   :uuid             not null, primary key
#  completed_at         :datetime
#  error_code           :string
#  error_message        :text
#  finish_reason        :string
#  input_snapshot       :jsonb            not null
#  latency_ms           :integer
#  provider             :string           not null
#  raw_response         :jsonb
#  started_at           :datetime
#  status               :string           not null
#  usage                :jsonb            not null
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  message_id           :uuid             not null
#  model_id             :string           not null
#  provider_request_id  :string
#  provider_response_id :string
#
# Indexes
#
#  index_model_runs_on_message_id         (message_id)
#  index_model_runs_on_provider_response  (provider,provider_response_id) UNIQUE WHERE (provider_response_id IS NOT NULL)
#
# Foreign Keys
#
#  fk_rails_...  (message_id => messages.id) ON DELETE => cascade
#
class ModelRun < ApplicationRecord
  STATUSES = %w[pending streaming complete failed].freeze
  IDENTITY_ATTRIBUTES = %w[message_id provider model_id input_snapshot].freeze

  belongs_to :message

  validates :provider, :model_id, presence: true
  validates :status, inclusion: {in: STATUSES}
  validates :latency_ms, numericality: {only_integer: true, greater_than_or_equal_to: 0}, allow_nil: true
  validate :usage_is_an_object
  validate :input_snapshot_is_an_object
  validate :raw_response_is_an_object
  validate :message_is_assistant
  validate :identity_is_immutable, on: :update

  private

  def usage_is_an_object
    errors.add(:usage, :invalid) unless usage.is_a?(Hash)
  end

  def input_snapshot_is_an_object
    errors.add(:input_snapshot, :invalid) unless input_snapshot.is_a?(Hash)
  end

  def raw_response_is_an_object
    errors.add(:raw_response, :invalid) if !raw_response.nil? && !raw_response.is_a?(Hash)
  end

  def message_is_assistant
    return if message_id.blank?

    role = if association(:message).loaded?
      association(:message).target&.role
    else
      Message.where(id: message_id).pick(:role)
    end
    errors.add(:message, :not_assistant) unless role == "assistant"
  end

  def identity_is_immutable
    return unless IDENTITY_ATTRIBUTES.any? { |attribute| will_save_change_to_attribute?(attribute) }

    errors.add(:base, :identity_immutable)
  end
end
