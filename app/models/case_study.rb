class CaseStudy < ApplicationRecord
  belongs_to :author, class_name: "User", optional: false
  has_many :contacts, class_name: "Contact", dependent: :destroy
  has_many :enrollments, class_name: "Enrollment", dependent: :destroy
  has_many :documents, class_name: "Document", dependent: :destroy

  validates :title, presence: true
  validates :title, length: {maximum: 200, allow_nil: true}
  validates :join_code, length: {maximum: 32, allow_nil: true}
  validates :join_code, uniqueness: {allow_nil: true}
  validates :published, inclusion: {in: [true, false]}

  normalizes :join_code, with: ->(code) { code.strip.upcase.presence }
end
