require "test_helper"
require_relative "domain_test_helper"

class ContactBriefingTest < ActiveSupport::TestCase
  include DomainTestHelper

  setup do
    @case_study = build_case_study
    @dana = build_contact(case_study: @case_study)
    @priya = build_contact(case_study: @case_study, full_name: "Priya Raghunathan")
  end

  def briefing_for(contact) = ContactBriefing.new(Contact.find(contact.id))

  test "carries the author's system prompt and the contact's identity" do
    text = briefing_for(@dana).system_text

    assert_match(/Dana Whitfield/, text)
    assert_match(/Chief Financial Officer/, text)
    assert_match(/Speak in numbers/, text)
  end

  test "offers no tools when a contact has nothing to give" do
    assert_empty briefing_for(@dana).tools
  end

  test "describes each referral with its condition" do
    Referral.create!(
      referring_contact: @dana, referred_contact: @priya,
      condition: "When the student pushes on causes in the plants."
    )

    text = briefing_for(@dana).system_text

    assert_match(/Priya Raghunathan/, text)
    assert_match(/pushes on causes in the plants/, text)
  end

  test "the introduce tool only admits contacts the author allowed" do
    Referral.create!(referring_contact: @dana, referred_contact: @priya, condition: "On plants.")
    unrelated = build_contact(case_study: @case_study, full_name: "Alice Chen")

    tool = briefing_for(@dana).tools.find { |t| t[:name] == ContactBriefing::INTRODUCE_TOOL }
    allowed = tool[:input_schema][:properties][:contact_id][:enum]

    assert_includes allowed, @priya.id
    assert_not_includes allowed, unrelated.id
  end

  test "a disabled referral is neither described nor offered" do
    Referral.create!(
      referring_contact: @dana, referred_contact: @priya,
      condition: "On plants.", enabled: false
    )

    briefing = briefing_for(@dana)

    assert_not_includes briefing.system_text, "Priya Raghunathan"
    assert_empty briefing.tools
  end

  test "the share tool only admits documents the contact holds" do
    held = build_document(case_study: @case_study)
    withheld = Document.create!(file_name: "ERP_spend.csv", case_study: @case_study)
    ShareRule.create!(contact: @dana, document: held, condition: "Once margin comes up.")

    tool = briefing_for(@dana).tools.find { |t| t[:name] == ContactBriefing::SHARE_TOOL }
    allowed = tool[:input_schema][:properties][:document_ids][:items][:enum]

    assert_includes allowed, held.id
    assert_not_includes allowed, withheld.id
    assert_match(/Once margin comes up/, briefing_for(@dana).system_text)
  end

  test "a contact who can both introduce and share gets both tools" do
    Referral.create!(referring_contact: @dana, referred_contact: @priya, condition: "On plants.")
    ShareRule.create!(contact: @dana, document: build_document(case_study: @case_study), condition: "On numbers.")

    names = briefing_for(@dana).tools.pluck(:name)

    assert_equal [ContactBriefing::INTRODUCE_TOOL, ContactBriefing::SHARE_TOOL].sort, names.sort
  end
end
