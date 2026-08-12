# == Schema Information
#
# Table name: share_rules
#
#  id          :uuid             not null, primary key
#  condition   :text             not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  contact_id  :uuid             not null
#  document_id :uuid             not null
#
# Indexes
#
#  index_share_rules_on_contact_id_and_document_id  (contact_id,document_id) UNIQUE
#  index_share_rules_on_document_id                 (document_id)
#
# Foreign Keys
#
#  fk_rails_...  (contact_id => contacts.id) ON DELETE => cascade
#  fk_rails_...  (document_id => documents.id) ON DELETE => cascade
#
class ShareRule < ApplicationRecord
  belongs_to :contact, class_name: "Contact", optional: false
  belongs_to :document, class_name: "Document", optional: false

  validates :condition, presence: true
  validates :document_id, uniqueness: {scope: :contact_id}
end
