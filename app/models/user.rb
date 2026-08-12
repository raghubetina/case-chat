class User < ApplicationRecord
  has_many :authored_cases, class_name: "CaseStudy", foreign_key: "author_id"
  has_many :enrollments, class_name: "Enrollment", foreign_key: "user_id"

  validates :full_name, presence: true
end
