class Document < ApplicationRecord
  belongs_to :case_study, class_name: "CaseStudy", optional: false

  validates :file_name, presence: true
  validates :byte_size, comparison: {greater_than: 0}, allow_nil: true
end
