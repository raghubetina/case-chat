# == Schema Information
#
# Table name: document_releases
#
#  id                 :uuid             not null, primary key
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  attempt_id         :uuid             not null
#  document_bundle_id :uuid             not null
#  message_id         :uuid             not null
#
# Indexes
#
#  index_document_releases_on_attempt_and_bundle  (attempt_id,document_bundle_id) UNIQUE
#  index_document_releases_on_document_bundle_id  (document_bundle_id)
#  index_document_releases_on_message_id          (message_id)
#
# Foreign Keys
#
#  fk_rails_...  (attempt_id => attempts.id) ON DELETE => cascade
#  fk_rails_...  (document_bundle_id => document_bundles.id) ON DELETE => restrict
#  fk_rails_...  (message_id => messages.id) ON DELETE => cascade
#
class DocumentRelease < ApplicationRecord
  belongs_to :attempt
  belongs_to :document_bundle
  belongs_to :message

  validates :document_bundle_id, uniqueness: {scope: :attempt_id}

  def document_snapshots
    snapshot = Attempt.where(id: attempt_id).pick(:configuration_snapshot)
    bundle = snapshot.fetch("bundles", {}).fetch(document_bundle_id)

    bundle.fetch("document_ids").map { |document_id| snapshot.fetch("documents").fetch(document_id) }
  end
end
