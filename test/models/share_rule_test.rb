require "test_helper"
require_relative "domain_test_helper"

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
class ShareRuleTest < ActiveSupport::TestCase
  include DomainTestHelper

  test "rejects a rule without a condition" do
    contact = build_contact
    rule = ShareRule.new(contact: contact, document: build_document(case_study: contact.case_study))

    assert_not rule.valid?
    assert rule.errors.of_kind?(:condition, :blank)
  end

  test "rejects a second rule for the same contact and document" do
    contact = build_contact
    document = build_document(case_study: contact.case_study)
    ShareRule.create!(contact: contact, document: document, condition: "Once margin comes up.")
    duplicate = ShareRule.new(contact: contact, document: document, condition: "Different words, same fact.")

    assert_not duplicate.valid?
    assert duplicate.errors.of_kind?(:document_id, :taken)
  end

  test "allows two contacts to share one document under different conditions" do
    case_study = build_case_study
    document = build_document(case_study: case_study)
    dana = build_contact(case_study: case_study)
    alice = build_contact(case_study: case_study, full_name: "Alice Chen")
    ShareRule.create!(contact: dana, document: document, condition: "Once margin comes up.")
    ShareRule.create!(contact: alice, document: document, condition: "If pushed on the allocation.")

    assert_equal [document], Contact.includes(:documents).find(dana.id).documents.to_a
    assert_equal [document], Contact.includes(:documents).find(alice.id).documents.to_a
  end
end
