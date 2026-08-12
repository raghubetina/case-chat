class Contact < ApplicationRecord
  belongs_to :case_study, class_name: "CaseStudy", foreign_key: "case_study_id", optional: false
  has_many :share_rules, class_name: "ShareRule", foreign_key: "contact_id"
  has_many :conversations, class_name: "Conversation", foreign_key: "contact_id"
  has_many :documents, -> { distinct }, through: :share_rules, source: :document

  validates :full_name, presence: true
  validates :role_title, presence: true
end
