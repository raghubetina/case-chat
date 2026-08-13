# == Schema Information
#
# Table name: enrollments
#
#  id         :uuid             not null, primary key
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  cohort_id  :uuid             not null
#  user_id    :uuid             not null
#
# Indexes
#
#  index_enrollments_on_cohort_id              (cohort_id)
#  index_enrollments_on_user_id_and_cohort_id  (user_id,cohort_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (cohort_id => cohorts.id) ON DELETE => restrict
#  fk_rails_...  (user_id => users.id) ON DELETE => restrict
#
class Enrollment < ApplicationRecord
  belongs_to :user
  belongs_to :cohort

  has_many :attempts, dependent: :restrict_with_exception

  validates :user_id, uniqueness: {scope: :cohort_id}
end
