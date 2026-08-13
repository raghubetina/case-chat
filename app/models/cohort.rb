# == Schema Information
#
# Table name: cohorts
#
#  id         :uuid             not null, primary key
#  due_at     :datetime
#  join_code  :string(32)       not null
#  name       :string(120)      not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  case_id    :uuid             not null
#
# Indexes
#
#  index_cohorts_on_case_id    (case_id)
#  index_cohorts_on_join_code  (join_code) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (case_id => cases.id) ON DELETE => restrict
#
class Cohort < ApplicationRecord
  belongs_to :case
  has_many :enrollments, dependent: :restrict_with_exception

  validates :name, :join_code, presence: true
  validates :name, length: {maximum: 120}
  validates :join_code, length: {maximum: 32}, uniqueness: true

  before_validation :canonicalize_fields

  private

  def canonicalize_fields
    self.name = name.to_s.strip
    self.join_code = join_code.to_s.strip.upcase
  end
end
