class Document < ApplicationRecord
  belongs_to :case_study, class_name: "CaseStudy", optional: false

  has_many :share_rules, class_name: "ShareRule", dependent: :destroy
  has_many :document_shares, class_name: "DocumentShare", dependent: :destroy

  validates :file_name, presence: true
  validates :byte_size, comparison: {greater_than: 0}, allow_nil: true
  validates :given_at_start, inclusion: {in: [true, false]}
end
