class Contact < ApplicationRecord
  belongs_to :case_study, class_name: "CaseStudy", optional: false
  has_many :share_rules, class_name: "ShareRule"
  has_many :conversations, class_name: "Conversation"
  has_many :documents, -> { distinct }, through: :share_rules, source: :document

  validates :full_name, presence: true
  validates :role_title, presence: true
end
