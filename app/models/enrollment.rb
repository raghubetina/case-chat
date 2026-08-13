class Enrollment < ApplicationRecord
  belongs_to :user, class_name: "User", optional: false
  belongs_to :case_study, class_name: "CaseStudy", optional: false
  has_many :conversations, class_name: "Conversation"
  has_many :introductions, class_name: "Introduction"
end
