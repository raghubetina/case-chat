require "test_helper"
require_relative "domain_test_helper"

class IntroductionTest < ActiveSupport::TestCase
  include DomainTestHelper

  test "records meeting a contact once per enrollment" do
    contact = build_contact
    enrollment = build_enrollment(case_study: contact.case_study)
    Introduction.create!(enrollment: enrollment, contact: contact)
    duplicate = Introduction.new(enrollment: enrollment, contact: contact)

    assert_not duplicate.valid?
    assert duplicate.errors.of_kind?(:contact_id, :taken)
  end

  test "allows re-meeting the same contact in a fresh enrollment" do
    contact = build_contact
    student = build_user
    first_run = build_enrollment(case_study: contact.case_study, user: student)
    Introduction.create!(enrollment: first_run, contact: contact)

    second_run = build_enrollment(case_study: contact.case_study, user: student)

    assert Introduction.create!(enrollment: second_run, contact: contact).persisted?
  end
end
