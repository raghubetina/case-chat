# == Schema Information
#
# Table name: contacts
#
#  id                    :uuid             not null, primary key
#  description           :text
#  effort                :string
#  full_name             :string           not null
#  in_starting_directory :boolean          default(FALSE), not null
#  knows_case_background :boolean          default(TRUE), not null
#  model                 :string
#  role_title            :string           not null
#  system_prompt         :text             not null
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  case_study_id         :uuid             not null
#
# Indexes
#
#  index_contacts_on_case_study_id_and_lower_full_name  (case_study_id, lower((full_name)::text)) UNIQUE
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
  has_many :documents, -> { distinct }, through: :share_rules, source: :document

  validates :full_name, presence: true
  # A cast is addressed by name; two Danas make every referral to "Dana" ambiguous.
  validates :full_name, uniqueness: {scope: :case_study_id, case_sensitive: false}
  validates :role_title, presence: true
  validates :system_prompt, presence: true
  # A closed list: a typo in a model id fails at the provider, mid-reply, in a
  # job. Blank means the deployment's default answers as this person.
  validates :model, inclusion: {in: ModelCatalogue.ids}, allow_blank: true
  validates :effort, inclusion: {in: ModelCatalogue.all_efforts}, allow_blank: true
  validate :effort_is_offered_by_the_model

  has_many :model_calls, class_name: "ModelCall", dependent: :destroy
  validates :in_starting_directory, inclusion: {in: [true, false]}
  validates :knows_case_background, inclusion: {in: [true, false]}

  private

  # Models disagree about which levels they accept — OpenAI offers minimal,
  # Anthropic offers max — so an effort that is valid somewhere can still be
  # wrong here.
  def effort_is_offered_by_the_model
    return if effort.blank? || model.blank?

    offered = ModelCatalogue.efforts_for(model)
    return if offered.empty? || offered.include?(effort)

    errors.add(:effort, :inclusion)
  end
end
