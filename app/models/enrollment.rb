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
