class CaseStudy < ApplicationRecord
  belongs_to :author, class_name: "User", foreign_key: "author_id", optional: false
  has_many :contacts, class_name: "Contact", foreign_key: "case_study_id"
  has_many :enrollments, class_name: "Enrollment", foreign_key: "case_study_id"
  has_many :documents, class_name: "Document", foreign_key: "case_study_id"

  validates :title, presence: true
  validates :title, length: { maximum: 200, allow_nil: true }
  validates :join_code, length: { maximum: 32, allow_nil: true }
end
