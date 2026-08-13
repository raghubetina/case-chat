# == Schema Information
#
# Table name: referrals
#
#  id                   :uuid             not null, primary key
#  condition            :text             not null
#  enabled              :boolean          default(TRUE), not null
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  referred_contact_id  :uuid             not null
#  referring_contact_id :uuid             not null
#
# Indexes
#
#  idx_on_referring_contact_id_referred_contact_id_0890d13c31  (referring_contact_id,referred_contact_id) UNIQUE
#  index_referrals_on_referred_contact_id                      (referred_contact_id)
#
# Foreign Keys
#
#  fk_rails_...  (referred_contact_id => contacts.id) ON DELETE => cascade
#  fk_rails_...  (referring_contact_id => contacts.id) ON DELETE => cascade
#
class Referral < ApplicationRecord
  belongs_to :referring_contact, class_name: "Contact", optional: false
  belongs_to :referred_contact, class_name: "Contact", optional: false

  validates :condition, presence: true
  validates :referred_contact_id, uniqueness: {scope: :referring_contact_id}
  validates :enabled, inclusion: {in: [true, false]}
end
