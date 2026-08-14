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

  test "tells a stakeholder which case they are standing in" do
    @case_study.update!(background: "Margin fell 380 basis points before the April review.")

    assert_match(/<case_background>/, briefing_for(@dana).system_text)
    assert_match(/380 basis points/, briefing_for(@dana).system_text)
  end

  # An outside party who is handed the case background stops being an outside
  # party: they answer from the situation rather than from their own corner of
  # it, which removes the reason the student had to go and ask them.
  test "an outsider can be kept out of the case background" do
    @case_study.update!(background: "Margin fell 380 basis points before the April review.")
    @dana.update!(knows_case_background: false)

    text = briefing_for(@dana).system_text

    assert_no_match(/case_background/, text)
    assert_no_match(/380 basis points/, text)
    assert_match(/Dana Whitfield/, text, "the persona still has to survive")
  end

  test "keeps each kind of content in its own block" do
    @case_study.update!(background: "Some background.")
    Referral.create!(referring_contact: @dana, referred_contact: @priya, condition: "On plants.")
    document = build_document(case_study: @case_study)
    ShareRule.create!(contact: @dana, document: document, condition: "On margin.")

    text = briefing_for(@dana).system_text

    %w[case_background who_you_are people_you_can_introduce documents_you_hold how_to_answer].each do |block|
      assert_match(/<#{block}>.*<\/#{block}>/m, text, "#{block} should be delimited")
    end
  end

  # Prompt formatting bleeds into reply formatting, and a person being
  # interviewed does not answer in headed bullet lists.
  test "asks for conversation rather than a memo" do
    text = briefing_for(@dana).system_text

    assert_match(/not in a memo/, text)
    assert_match(/Do not use headings, bullet lists/, text)
  end
end
