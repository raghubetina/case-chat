class CaseStudy < ApplicationRecord
  belongs_to :author, class_name: "User", optional: false
  has_many :contacts, class_name: "Contact"
  has_many :enrollments, class_name: "Enrollment"
  has_many :documents, class_name: "Document"

  validates :title, presence: true
  validates :title, length: {maximum: 200, allow_nil: true}
  validates :join_code, length: {maximum: 32, allow_nil: true}
end
