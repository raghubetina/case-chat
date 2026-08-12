class User < ApplicationRecord
  has_many :authored_cases, class_name: "CaseStudy", foreign_key: "author_id", dependent: :restrict_with_error
  has_many :enrollments, class_name: "Enrollment", dependent: :destroy

  validates :full_name, presence: true
end
