# == Schema Information
#
# Table name: conversations
#
#  id                     :uuid             not null, primary key
#  configuration_snapshot :jsonb            not null
#  provider               :string           not null
#  provider_cursor        :string
#  slot                   :string
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  attempt_id             :uuid
#  model_id               :string           not null
#  stakeholder_id         :uuid             not null
#  test_drive_id          :uuid
#
# Indexes
#
#  index_conversations_on_attempt_and_stakeholder  (attempt_id,stakeholder_id) UNIQUE WHERE (attempt_id IS NOT NULL)
#  index_conversations_on_attempt_id               (attempt_id)
#  index_conversations_on_stakeholder_id           (stakeholder_id)
#  index_conversations_on_test_drive_and_slot      (test_drive_id,slot) UNIQUE WHERE (test_drive_id IS NOT NULL)
#  index_conversations_on_test_drive_id            (test_drive_id)
#
# Foreign Keys
#
#  fk_rails_...  (attempt_id => attempts.id) ON DELETE => cascade
#  fk_rails_...  (stakeholder_id => stakeholders.id) ON DELETE => restrict
#  fk_rails_...  (test_drive_id => test_drives.id) ON DELETE => cascade
#
class Conversation < ApplicationRecord
  CONTEXT_ATTRIBUTES = %w[stakeholder_id attempt_id test_drive_id slot].freeze
  MESSAGE_PINNED_ATTRIBUTES = %w[provider model_id configuration_snapshot].freeze

  belongs_to :stakeholder
  belongs_to :attempt, optional: true
  belongs_to :test_drive, optional: true

  has_many :messages, dependent: :delete_all

  validates :provider, :model_id, presence: true
  validate :has_one_valid_context
  validate :stakeholder_belongs_to_context
  validate :configuration_snapshot_is_an_object
  validate :context_is_immutable, on: :update
  validate :configuration_is_pinned_after_first_message, on: :update

  private

  def has_one_valid_context
    learner_context = attempt_id.present? && test_drive_id.blank? && slot.blank?
    test_context = attempt_id.blank? && test_drive_id.present? && %w[left right].include?(slot)
    errors.add(:base, :invalid_context) unless learner_context || test_context
  end

  def stakeholder_belongs_to_context
    snapshot = context_snapshot
    return if snapshot.nil?

    stakeholder_ids = snapshot.fetch("stakeholders", {}).keys
    stakeholder_ids << snapshot.dig("stakeholder", "id")
    valid_snapshot_member = stakeholder_ids.compact.include?(stakeholder_id)
    valid_test_drive_member = test_drive_id.blank? || test_drive_stakeholder_id == stakeholder_id
    unless valid_snapshot_member && valid_test_drive_member
      errors.add(:stakeholder, :different_context)
    end
  end

  def context_snapshot
    if attempt_id.present?
      Attempt.where(id: attempt_id).pick(:configuration_snapshot)
    elsif test_drive_id.present?
      TestDrive.where(id: test_drive_id).pick(:configuration_snapshot)
    end
  end

  def configuration_is_pinned_after_first_message
    return unless MESSAGE_PINNED_ATTRIBUTES.any? { |attribute| will_save_change_to_attribute?(attribute) }
    return unless Message.where(conversation_id: id).exists?

    errors.add(:base, :configuration_pinned)
  end

  def context_is_immutable
    return unless CONTEXT_ATTRIBUTES.any? { |attribute| will_save_change_to_attribute?(attribute) }

    errors.add(:base, :context_immutable)
  end

  def test_drive_stakeholder_id
    TestDrive.where(id: test_drive_id).pick(:stakeholder_id)
  end

  def configuration_snapshot_is_an_object
    errors.add(:configuration_snapshot, :invalid) unless configuration_snapshot.is_a?(Hash)
  end
end
