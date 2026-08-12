# == Schema Information
#
# Table name: case_studies
#
#  id         :uuid             not null, primary key
#  assignment :text
#  background :text
#  course     :string
#  due_at     :datetime
#  join_code  :string(32)
#  published  :boolean          default(FALSE), not null
#  title      :string(200)      not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  author_id  :uuid             not null
#
# Indexes
#
#  index_case_studies_on_author_id  (author_id)
#  index_case_studies_on_join_code  (join_code) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (author_id => users.id) ON DELETE => restrict
#
class CaseStudy < ApplicationRecord
  belongs_to :author, class_name: "User", optional: false
  has_many :contacts, class_name: "Contact", dependent: :destroy
  has_many :enrollments, class_name: "Enrollment", dependent: :destroy
  has_many :documents, class_name: "Document", dependent: :destroy
  has_one :case_draft, class_name: "CaseDraft", dependent: :destroy

  validates :title, presence: true
  validates :title, length: {maximum: 200, allow_nil: true}
  validates :join_code, length: {maximum: 32, allow_nil: true}
  validates :join_code, uniqueness: {allow_nil: true}
  validates :published, inclusion: {in: [true, false]}

  normalizes :join_code, with: ->(code) { code.strip.upcase.presence }

  scope :joinable, -> { where(published: true).where.not(join_code: nil) }

  def self.find_by_join_code(code)
    joinable.find_by(join_code: code.to_s.strip.upcase.presence)
  end
end
