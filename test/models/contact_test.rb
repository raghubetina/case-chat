require "test_helper"
require_relative "domain_test_helper"

# == Schema Information
#
# Table name: contacts
#
#  id                    :uuid             not null, primary key
#  description           :text
#  full_name             :string           not null
#  in_starting_directory :boolean          default(FALSE), not null
#  knows_case_background :boolean          default(TRUE), not null
#  role_title            :string           not null
#  system_prompt         :text             not null
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  case_study_id         :uuid             not null
#
# Indexes
#
#  index_contacts_on_case_study_id_and_lower_full_name  (case_study_id, lower((full_name)::text)) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (case_study_id => case_studies.id) ON DELETE => cascade
#
class ContactTest < ActiveSupport::TestCase
  include DomainTestHelper

  should belong_to(:case_study)
  should have_many(:share_rules).dependent(:destroy)
  should have_many(:conversations).dependent(:destroy)
  should have_many(:documents).through(:share_rules)

  # Referrals are one table read from both ends; the names are the only thing
  # keeping "who referred whom" straight.
  should have_many(:outgoing_referrals).class_name("Referral")
    .with_foreign_key("referring_contact_id").dependent(:destroy)
  should have_many(:incoming_referrals).class_name("Referral")
    .with_foreign_key("referred_contact_id").dependent(:destroy)

  # Deleting someone from the cast must not delete the fact that a student met
  # the people they introduced.
  should have_many(:introductions_made).class_name("Introduction")
    .with_foreign_key("introducing_contact_id").dependent(:nullify)
  should have_many(:introducing_messages).class_name("Message")
    .with_foreign_key("introduced_contact_id").dependent(:nullify)

  should validate_presence_of(:full_name)
  should validate_presence_of(:role_title)
  should validate_presence_of(:system_prompt)

  test "rejects two people with the same name in one case" do
    dana = build_contact
    duplicate = Contact.new(
      full_name: dana.full_name.downcase, role_title: "Analyst",
      system_prompt: "You are someone else.", case_study: dana.case_study
    )

    assert_not duplicate.valid?
    assert duplicate.errors.of_kind?(:full_name, :taken)
  end
end
