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
#  index_referrals_on_referred_contact_id   (referred_contact_id)
#  index_referrals_on_referring_contact_id  (referring_contact_id)
#
# Foreign Keys
#
#  fk_rails_...  (referred_contact_id => contacts.id) ON DELETE => cascade
#  fk_rails_...  (referring_contact_id => contacts.id) ON DELETE => cascade
#
class ReferralTest < ActiveSupport::TestCase
  include DomainTestHelper

  test "rejects a referral without a condition" do
    case_study = build_case_study
    referral = Referral.new(
      referring_contact: build_contact(case_study: case_study),
      referred_contact: build_contact(case_study: case_study, full_name: "Priya Raghunathan")
    )

    assert_not referral.valid?
    assert referral.errors.of_kind?(:condition, :blank)
  end

  test "defaults enabled to true" do
    case_study = build_case_study
    referral = Referral.create!(
      referring_contact: build_contact(case_study: case_study),
      referred_contact: build_contact(case_study: case_study, full_name: "Priya Raghunathan"),
      condition: "When the student pushes on causes in the plants."
    )

    assert_equal true, referral.enabled
  end

  test "is reachable from both contacts' referral edges" do
    case_study = build_case_study
    dana = build_contact(case_study: case_study)
    priya = build_contact(case_study: case_study, full_name: "Priya Raghunathan")
    referral = Referral.create!(referring_contact: dana, referred_contact: priya, condition: "On plant specifics.")

    assert_equal [referral], Contact.includes(:outgoing_referrals).find(dana.id).outgoing_referrals.to_a
    assert_equal [referral], Contact.includes(:incoming_referrals).find(priya.id).incoming_referrals.to_a
  end
end
