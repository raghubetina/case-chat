# == Schema Information
#
# Table name: attempts
#
#  id                     :uuid             not null, primary key
#  configuration_snapshot :jsonb            not null
#  ended_at               :datetime
#  sequence               :integer          not null
#  started_at             :datetime         not null
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  enrollment_id          :uuid             not null
#
# Indexes
#
#  index_attempts_on_enrollment_id_and_sequence  (enrollment_id,sequence) UNIQUE
#  index_attempts_on_open_enrollment             (enrollment_id) UNIQUE WHERE (ended_at IS NULL)
#
# Foreign Keys
#
#  fk_rails_...  (enrollment_id => enrollments.id) ON DELETE => restrict
#
class Attempt < ApplicationRecord
  LEARNER_STAKEHOLDER_ATTRIBUTES = %w[id name role_title description].freeze
  LEARNER_DOCUMENT_ATTRIBUTES = %w[id title description learner_text].freeze
  LEARNER_ATTACHMENT_ATTRIBUTES = %w[filename content_type byte_size].freeze

  belongs_to :enrollment

  has_many :conversations, dependent: :delete_all
  has_many :introductions, dependent: :delete_all
  has_many :document_releases, dependent: :delete_all

  validates :started_at, presence: true
  validates :sequence, numericality: {only_integer: true, greater_than: 0}
  validate :configuration_snapshot_is_an_object
  validate :configuration_snapshot_is_immutable, on: :update

  def available_stakeholder_snapshots
    introduced_ids = Introduction.where(attempt_id: id).pluck(:target_stakeholder_id)

    configuration_snapshot.fetch("stakeholders", {}).values.filter_map do |stakeholder|
      next unless stakeholder.fetch("available_at_start") || introduced_ids.include?(stakeholder.fetch("id"))

      stakeholder.slice(*LEARNER_STAKEHOLDER_ATTRIBUTES)
    end
  end

  def available_document_snapshots
    released_bundle_ids = DocumentRelease.where(attempt_id: id).pluck(:document_bundle_id)
    released_document_ids = configuration_snapshot.fetch("bundles", {}).values
      .select { |bundle| released_bundle_ids.include?(bundle.fetch("id")) }
      .flat_map { |bundle| bundle.fetch("document_ids") }

    configuration_snapshot.fetch("documents", {}).values.filter_map do |document|
      next unless document.fetch("available_at_start") || released_document_ids.include?(document.fetch("id"))

      document.slice(*LEARNER_DOCUMENT_ATTRIBUTES).tap do |learner_document|
        learner_document["attachment"] = document.fetch("attachment", nil)&.slice(*LEARNER_ATTACHMENT_ATTRIBUTES)
      end
    end
  end

  private

  def configuration_snapshot_is_an_object
    errors.add(:configuration_snapshot, :invalid) unless configuration_snapshot.is_a?(Hash)
  end

  def configuration_snapshot_is_immutable
    return unless will_save_change_to_configuration_snapshot?

    errors.add(:configuration_snapshot, :immutable)
  end
end
