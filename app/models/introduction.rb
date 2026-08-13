# == Schema Information
#
# Table name: introductions
#
#  id                    :uuid             not null, primary key
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  attempt_id            :uuid             not null
#  message_id            :uuid             not null
#  target_stakeholder_id :uuid             not null
#
# Indexes
#
#  index_introductions_on_attempt_and_target     (attempt_id,target_stakeholder_id) UNIQUE
#  index_introductions_on_message_id             (message_id)
#  index_introductions_on_target_stakeholder_id  (target_stakeholder_id)
#
# Foreign Keys
#
#  fk_rails_...  (attempt_id => attempts.id) ON DELETE => cascade
#  fk_rails_...  (message_id => messages.id) ON DELETE => cascade
#  fk_rails_...  (target_stakeholder_id => stakeholders.id) ON DELETE => restrict
#
class Introduction < ApplicationRecord
  belongs_to :attempt
  belongs_to :target_stakeholder, class_name: "Stakeholder", inverse_of: :introductions
  belongs_to :message

  validates :target_stakeholder_id, uniqueness: {scope: :attempt_id}
end
