# == Schema Information
#
# Table name: contacts
#
#  id                    :uuid             not null, primary key
#  description           :text
#  full_name             :string           not null
#  in_starting_directory :boolean          default(FALSE), not null
#  role_title            :string           not null
#  system_prompt         :text             not null
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  case_study_id         :uuid             not null
#
# Indexes
#
#  index_contacts_on_case_study_id  (case_study_id)
#
# Foreign Keys
#
#  fk_rails_...  (case_study_id => case_studies.id) ON DELETE => cascade
#
class Contact < ApplicationRecord
  belongs_to :case_study, class_name: "CaseStudy", optional: false
  has_many :share_rules, class_name: "ShareRule", dependent: :destroy
  has_many :conversations, class_name: "Conversation", dependent: :destroy
  has_many :outgoing_referrals, class_name: "Referral", foreign_key: "referring_contact_id", dependent: :destroy
  has_many :incoming_referrals, class_name: "Referral", foreign_key: "referred_contact_id", dependent: :destroy
  has_many :introductions, class_name: "Introduction", dependent: :destroy
  has_many :introductions_made, class_name: "Introduction", foreign_key: "introducing_contact_id", dependent: :nullify
  has_many :introducing_messages, class_name: "Message", foreign_key: "introduced_contact_id", dependent: :nullify
  has_many :documents, -> { distinct }, through: :share_rules, source: :document

  validates :full_name, presence: true
  validates :role_title, presence: true
  validates :system_prompt, presence: true
  validates :in_starting_directory, inclusion: {in: [true, false]}
end
