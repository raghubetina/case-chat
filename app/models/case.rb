# == Schema Information
#
# Table name: cases
#
#  id                      :uuid             not null, primary key
#  assignment              :text             default(""), not null
#  background              :text             default(""), not null
#  published_at            :datetime
#  published_configuration :jsonb
#  status                  :string           default("draft"), not null
#  title                   :string(200)      not null
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  author_id               :uuid             not null
#
# Indexes
#
#  index_cases_on_author_id  (author_id)
#
# Foreign Keys
#
#  fk_rails_...  (author_id => users.id) ON DELETE => restrict
#
class Case < ApplicationRecord
  DRAFT_EDITABLE_ATTRIBUTES = %i[title background assignment].freeze
  STATUSES = %w[draft published archived].freeze

  belongs_to :author, class_name: "User", inverse_of: :authored_cases

  has_many :cohorts, dependent: :restrict_with_exception
  has_many :stakeholders, dependent: :restrict_with_exception
  has_many :case_documents, dependent: :restrict_with_exception

  validates :title, presence: true, length: {maximum: 200}
  validates :status, inclusion: {in: STATUSES}
end
