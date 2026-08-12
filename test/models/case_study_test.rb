require "test_helper"
require_relative "domain_test_helper"

class CaseStudyTest < ActiveSupport::TestCase
  include DomainTestHelper

  test "accepts a complete case study" do
    assert build_case_study.persisted?
  end

  test "defaults published to false" do
    assert_equal false, build_case_study.published
  end

  test "normalizes join codes to trimmed uppercase" do
    case_study = build_case_study
    case_study.update!(join_code: "  calder-04 ")

    assert_equal "CALDER-04", case_study.join_code
  end

  test "rejects a duplicate join code" do
    author = build_user
    build_case_study(author: author).update!(join_code: "CALDER-04")
    duplicate = CaseStudy.new(title: "Other", author: author, join_code: "calder-04")

    assert_not duplicate.valid?
    assert duplicate.errors.of_kind?(:join_code, :taken)
  end

  test "destroys its cast, documents, and enrollments with it" do
    contact = build_contact
    case_study = contact.case_study
    build_document(case_study: case_study)
    build_enrollment(case_study: case_study)

    case_study.destroy!

    assert_equal 0, Contact.count
    assert_equal 0, Document.count
    assert_equal 0, Enrollment.count
  end
end
