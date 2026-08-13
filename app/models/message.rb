# == Schema Information
#
# Table name: messages
#
#  id              :uuid             not null, primary key
#  content         :text             default(""), not null
#  position        :integer          not null
#  role            :string           not null
#  status          :string           not null
#  tool_name       :string
#  tool_result     :jsonb
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  conversation_id :uuid             not null
#  tool_call_id    :string
#
# Indexes
#
#  index_messages_on_conversation_and_tool_call    (conversation_id,tool_call_id) UNIQUE WHERE (tool_call_id IS NOT NULL)
#  index_messages_on_conversation_id_and_position  (conversation_id,position) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (conversation_id => conversations.id) ON DELETE => cascade
#
class Message < ApplicationRecord
  ROLES = %w[user assistant tool].freeze
  STATUSES = %w[pending streaming complete failed].freeze

  belongs_to :conversation

  has_many :model_runs, dependent: :delete_all
  has_many :introductions, dependent: :delete_all
  has_many :document_releases, dependent: :delete_all

  validates :position, numericality: {only_integer: true, greater_than: 0},
    uniqueness: {scope: :conversation_id}
  validates :role, inclusion: {in: ROLES}
  validates :status, inclusion: {in: STATUSES}
  validate :non_assistant_message_is_complete
  validate :tool_metadata_matches_role
  validate :identity_is_immutable, on: :update

  private

  def non_assistant_message_is_complete
    return if role == "assistant" || status == "complete"

    errors.add(:status, :must_be_complete)
  end

  def tool_metadata_matches_role
    metadata = [tool_name, tool_call_id, tool_result]
    valid = if role == "tool"
      tool_name.present? && tool_call_id.present? && tool_result.is_a?(Hash)
    else
      metadata.all?(&:nil?)
    end
    errors.add(:base, :invalid_tool_metadata) unless valid
  end

  def identity_is_immutable
    return unless will_save_change_to_conversation_id? || will_save_change_to_position? || will_save_change_to_role?

    errors.add(:base, :identity_immutable)
  end
end
