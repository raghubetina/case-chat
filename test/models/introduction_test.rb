require "test_helper"
require_relative "domain_test_helper"

# == Schema Information
#
# Table name: introductions
#
#  id                     :uuid             not null, primary key
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  contact_id             :uuid             not null
#  enrollment_id          :uuid             not null
#  introducing_contact_id :uuid
#
# Indexes
#
#  index_introductions_on_contact_id                    (contact_id)
#  index_introductions_on_enrollment_id_and_contact_id  (enrollment_id,contact_id) UNIQUE
#  index_introductions_on_introducing_contact_id        (introducing_contact_id)
#
# Foreign Keys
#
#  fk_rails_...  (contact_id => contacts.id) ON DELETE => cascade
#  fk_rails_...  (enrollment_id => enrollments.id) ON DELETE => cascade
#  fk_rails_...  (introducing_contact_id => contacts.id) ON DELETE => nullify
#
class IntroductionTest < ActiveSupport::TestCase
  include DomainTestHelper

  should belong_to(:enrollment)
  should belong_to(:contact)
  should belong_to(:introducing_contact).class_name("Contact").optional

  test "records meeting a contact once per run" do
    contact = build_contact
    enrollment = build_enrollment(case_study: contact.case_study)
    Introduction.create!(enrollment: enrollment, contact: contact)
    duplicate = Introduction.new(enrollment: enrollment, contact: contact)

    assert_not duplicate.valid?
    assert duplicate.errors.of_kind?(:contact_id, :taken)
  end

  # Restarting a case has to put the directory back to the people you begin
  # with, which means meeting someone again has to be allowed.
  test "allows re-meeting the same contact in a fresh run" do
    contact = build_contact
    student = build_user
    first_run = build_enrollment(case_study: contact.case_study, user: student)
    Introduction.create!(enrollment: first_run, contact: contact)

    second_run = build_enrollment(case_study: contact.case_study, user: student)

    assert Introduction.create!(enrollment: second_run, contact: contact).persisted?
  end
end
