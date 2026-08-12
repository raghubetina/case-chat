# == Schema Information
#
# Table name: enrollments
#
#  id             :uuid             not null, primary key
#  last_active_at :datetime
#  started_at     :datetime         not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  case_study_id  :uuid             not null
#  user_id        :uuid             not null
#
# Indexes
#
#  index_enrollments_on_case_study_id  (case_study_id)
#  index_enrollments_on_student_runs   (user_id,case_study_id,started_at DESC)
#
# Foreign Keys
#
#  fk_rails_...  (case_study_id => case_studies.id) ON DELETE => cascade
#  fk_rails_...  (user_id => users.id) ON DELETE => cascade
#
class Enrollment < ApplicationRecord
  belongs_to :user, class_name: "User", optional: false
  belongs_to :case_study, class_name: "CaseStudy", optional: false
  has_many :conversations, class_name: "Conversation", dependent: :destroy
  has_many :introductions, class_name: "Introduction", dependent: :destroy

  validates :started_at, presence: true

  before_validation { self.started_at ||= Time.current }

  scope :newest_first, -> { order(started_at: :desc) }

  # Only the newest run of a case is live; earlier ones are read-only history.
  def current?
    id == self.class.where(user_id: user_id, case_study_id: case_study_id)
      .newest_first
      .pick(:id)
  end

  def run_number
    self.class.where(user_id: user_id, case_study_id: case_study_id)
      .where(started_at: ..started_at).count
  end
end
