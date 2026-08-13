# == Schema Information
#
# Table name: test_drives
#
#  id                     :uuid             not null, primary key
#  configuration_snapshot :jsonb            not null
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  author_id              :uuid             not null
#  stakeholder_id         :uuid             not null
#
# Indexes
#
#  index_test_drives_on_author_id       (author_id)
#  index_test_drives_on_stakeholder_id  (stakeholder_id)
#
# Foreign Keys
#
#  fk_rails_...  (author_id => users.id) ON DELETE => restrict
#  fk_rails_...  (stakeholder_id => stakeholders.id) ON DELETE => restrict
#
class TestDrive < ApplicationRecord
  IMMUTABLE_ATTRIBUTES = %w[author_id stakeholder_id configuration_snapshot].freeze

  belongs_to :author, class_name: "User", inverse_of: :test_drives
  belongs_to :stakeholder

  has_many :conversations, dependent: :delete_all

  validate :author_owns_stakeholder_case
  validate :configuration_snapshot_is_an_object
  validate :identity_is_immutable, on: :update

  private

  def author_owns_stakeholder_case
    return if author_id.blank? || stakeholder_id.blank?

    case_author_id = Case.joins(:stakeholders).where(stakeholders: {id: stakeholder_id}).pick(:author_id)
    errors.add(:stakeholder, :not_owned) unless case_author_id == author_id
  end

  def identity_is_immutable
    return unless IMMUTABLE_ATTRIBUTES.any? { |attribute| will_save_change_to_attribute?(attribute) }

    errors.add(:base, :identity_immutable)
  end

  def configuration_snapshot_is_an_object
    errors.add(:configuration_snapshot, :invalid) unless configuration_snapshot.is_a?(Hash)
  end
end
