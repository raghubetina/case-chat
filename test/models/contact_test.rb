require "test_helper"
require_relative "domain_test_helper"

class ContactTest < ActiveSupport::TestCase
  include DomainTestHelper

  test "rejects a contact without a system prompt" do
    contact = Contact.new(full_name: "Dana", role_title: "CFO", case_study: build_case_study)

    assert_not contact.valid?
    assert contact.errors.of_kind?(:system_prompt, :blank)
  end

  test "defaults in_starting_directory to false" do
    assert_equal false, build_contact.in_starting_directory
  end

  test "nullifies introductions it made when destroyed" do
    case_study = build_case_study
    dana = build_contact(case_study: case_study)
    priya = build_contact(case_study: case_study, full_name: "Priya Raghunathan")
    enrollment = build_enrollment(case_study: case_study)
    introduction = Introduction.create!(enrollment: enrollment, contact: priya, introducing_contact: dana)

    dana.destroy!

    assert_nil introduction.reload.introducing_contact_id
  end
end
