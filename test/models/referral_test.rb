require "test_helper"
require_relative "domain_test_helper"

# == Schema Information
#
# Table name: referrals
#
#  id                   :uuid             not null, primary key
#  condition            :text             not null
#  enabled              :boolean          default(TRUE), not null
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  referred_contact_id  :uuid             not null
#  referring_contact_id :uuid             not null
#
# Indexes
#
#  idx_on_referring_contact_id_referred_contact_id_0890d13c31  (referring_contact_id,referred_contact_id) UNIQUE
#  index_referrals_on_referred_contact_id                      (referred_contact_id)
#
# Foreign Keys
#
#  fk_rails_...  (referred_contact_id => contacts.id) ON DELETE => cascade
#  fk_rails_...  (referring_contact_id => contacts.id) ON DELETE => cascade
#
class ReferralTest < ActiveSupport::TestCase
  include DomainTestHelper

  should belong_to(:referring_contact).class_name("Contact")
  should belong_to(:referred_contact).class_name("Contact")

  should validate_presence_of(:condition)

  # One person cannot introduce the same person twice; the second condition
  # would silently never fire.
  test "rejects a second referral between the same two people" do
    case_study = build_case_study
    dana = build_contact(case_study: case_study)
    priya = build_contact(case_study: case_study, full_name: "Priya Raghunathan")
    Referral.create!(referring_contact: dana, referred_contact: priya, condition: "On plant specifics.")
    duplicate = Referral.new(referring_contact: dana, referred_contact: priya, condition: "Different words.")

    assert_not duplicate.valid?
    assert duplicate.errors.of_kind?(:referred_contact_id, :taken)
  end
end
