class Enrollment < ApplicationRecord
  belongs_to :user, class_name: "User", foreign_key: "user_id", optional: false
  belongs_to :case_study, class_name: "CaseStudy", foreign_key: "case_study_id", optional: false
  has_many :conversations, class_name: "Conversation", foreign_key: "enrollment_id"
  has_many :introductions, class_name: "Introduction", foreign_key: "enrollment_id"
end
