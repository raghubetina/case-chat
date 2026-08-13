# == Schema Information
#
# Table name: referrals
#
#  id                    :uuid             not null, primary key
#  guidance              :text             default(""), not null
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  source_stakeholder_id :uuid             not null
#  target_stakeholder_id :uuid             not null
#
# Indexes
#
#  index_referrals_on_source_and_target      (source_stakeholder_id,target_stakeholder_id) UNIQUE
#  index_referrals_on_target_stakeholder_id  (target_stakeholder_id)
#
# Foreign Keys
#
#  fk_rails_...  (source_stakeholder_id => stakeholders.id) ON DELETE => cascade
#  fk_rails_...  (target_stakeholder_id => stakeholders.id) ON DELETE => cascade
#
class Referral < ApplicationRecord
  belongs_to :source_stakeholder, class_name: "Stakeholder", inverse_of: :outgoing_referrals
  belongs_to :target_stakeholder, class_name: "Stakeholder", inverse_of: :incoming_referrals

  validates :target_stakeholder_id, uniqueness: {scope: :source_stakeholder_id}
  validate :different_endpoints
  validate :endpoints_share_case

  private

  def different_endpoints
    return if source_stakeholder_id.blank? || source_stakeholder_id != target_stakeholder_id

    errors.add(:target_stakeholder, :self_referral)
  end

  def endpoints_share_case
    return if source_stakeholder_id.blank? || target_stakeholder_id.blank?
    return if stakeholder_case_id(:source_stakeholder) == stakeholder_case_id(:target_stakeholder)

    errors.add(:target_stakeholder, :different_case)
  end

  def stakeholder_case_id(name)
    association = association(name)
    return association.target&.case_id if association.loaded?

    Stakeholder.where(id: public_send("#{name}_id")).pick(:case_id)
  end
end
