# == Schema Information
#
# Table name: stakeholders
#
#  id                      :uuid             not null, primary key
#  available_at_start      :boolean          default(FALSE), not null
#  description             :text             default(""), not null
#  included_in_publication :boolean          default(TRUE), not null
#  instructions            :text             default(""), not null
#  knows_case_background   :boolean          default(TRUE), not null
#  name                    :string(120)      not null
#  provider                :string
#  provider_settings       :jsonb            not null
#  publication_locked_at   :datetime
#  role_title              :string(160)      not null
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  case_id                 :uuid             not null
#  model_id                :string
#
# Indexes
#
#  index_stakeholders_on_case_id  (case_id)
#
# Foreign Keys
#
#  fk_rails_...  (case_id => cases.id) ON DELETE => restrict
#
class Stakeholder < ApplicationRecord
  belongs_to :case

  has_many :outgoing_referrals, class_name: "Referral", foreign_key: :source_stakeholder_id,
    inverse_of: :source_stakeholder, dependent: :delete_all
  has_many :incoming_referrals, class_name: "Referral", foreign_key: :target_stakeholder_id,
    inverse_of: :target_stakeholder, dependent: :delete_all
  has_many :document_bundles, dependent: :destroy, strict_loading: false
  has_many :conversations
  has_many :test_drives, class_name: "TestDrive", dependent: :destroy, strict_loading: false
  has_many :introductions, foreign_key: :target_stakeholder_id,
    inverse_of: :target_stakeholder

  validates :name, :role_title, presence: true
  validates :name, length: {maximum: 120}
  validates :role_title, length: {maximum: 160}
  validates :available_at_start, :included_in_publication, :knows_case_background,
    inclusion: {in: [true, false]}
  validate :provider_settings_is_an_object
  before_destroy :prevent_published_destroy, prepend: true

  private

  def provider_settings_is_an_object
    return if provider_settings.is_a?(Hash)

    errors.add(:provider_settings, :invalid)
  end

  def prevent_published_destroy
    return unless self.class.where(id:).where.not(publication_locked_at: nil).exists?

    errors.add(:base, :published)
    throw :abort
  end
end
