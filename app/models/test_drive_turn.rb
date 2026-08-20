# One line of a rehearsal. `text`, `from_contact?`, `introduced_ids` and
# `shared_ids` keep the names the cache-backed Struct used, so the partials that
# render a turn did not have to learn a new shape.
# == Schema Information
#
# Table name: test_drive_turns
#
#  id                     :uuid             not null, primary key
#  body                   :text             not null
#  from_contact           :boolean          default(FALSE), not null
#  introduced_contact_ids :jsonb            not null
#  shared_document_ids    :jsonb            not null
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  test_drive_id          :uuid             not null
#
# Indexes
#
#  index_test_drive_turns_on_test_drive_id_and_created_at  (test_drive_id,created_at)
#
# Foreign Keys
#
#  fk_rails_...  (test_drive_id => test_drives.id) ON DELETE => cascade
#
class TestDriveTurn < ApplicationRecord
  belongs_to :test_drive, class_name: "TestDrive", optional: false

  # Matches Message: a contact's turn can be an act rather than words, and a
  # reply that only introduced someone carries no prose. Validating it presence
  # here raised RecordInvalid inside the job, which streamed the answer to the
  # screen and then never replaced the row it was streaming into.
  validates :body, presence: true, unless: :from_contact?

  alias_attribute :text, :body

  def introduced_ids = introduced_contact_ids
  def shared_ids = shared_document_ids
end
