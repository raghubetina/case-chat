require "test_helper"
require_relative "domain_test_helper"

# Every figure in the cohort report is read off the transcript, so these tests
# build real transcripts rather than asserting on precomputed counters.
class CohortReportTest < ActiveSupport::TestCase
  include DomainTestHelper

  setup do
    @case_study = build_case_study
    @dana = build_contact(case_study: @case_study)
    @dana.update!(in_starting_directory: true)
    @priya = build_contact(case_study: @case_study, full_name: "Priya Raghunathan")
    @document = build_document(case_study: @case_study)
  end

  def enroll(name)
    user = User.create!(full_name: name, email: "#{name.parameterize}@example.test", status: 2)
    Enrollment.create!(user: user, case_study: @case_study)
  end

  def interview(enrollment, contact, messages: 1)
    conversation = Conversation.find_or_create_by!(enrollment: enrollment, contact: contact)
    messages.times do
      Message.create!(conversation: conversation, body: "question", sent_at: Time.current, from_contact: false)
      Message.create!(conversation: conversation, body: "answer", sent_at: Time.current, from_contact: true)
    end
    conversation
  end

  test "an empty cohort reports zeroes rather than blowing up" do
    report = CohortReport.new(@case_study)

    assert_equal 0, report.enrolled_count
    assert_equal 0, report.median_contacts_met
    assert_equal 0, report.started_count
  end

  test "counts only the student's own messages as effort" do
    enrollment = enroll("Lena Ahmed")
    interview(enrollment, @dana, messages: 3)

    report = CohortReport.new(@case_study)

    assert_equal 3, report.students.first.messages_sent
  end

  test "a student who joined but never wrote has not started" do
    enroll("Owen Fanning")

    report = CohortReport.new(@case_study)

    assert_equal 1, report.enrolled_count
    assert_equal 0, report.started_count
  end

  test "everyone in the starting directory counts as met" do
    enroll("Lena Ahmed")

    report = CohortReport.new(@case_study)

    # Dana is in the starting directory; Priya has to be earned.
    assert_equal 1, report.students.first.contacts_met
  end

  test "an earned introduction raises the contacts-met count" do
    enrollment = enroll("Lena Ahmed")
    Introduction.create!(enrollment: enrollment, contact: @priya, introducing_contact: @dana)

    report = CohortReport.new(@case_study)

    assert_equal 2, report.students.first.contacts_met
  end

  test "reach reports the share of students who found each contact" do
    first = enroll("Lena Ahmed")
    enroll("Noah Baptiste")
    Introduction.create!(enrollment: first, contact: @priya, introducing_contact: @dana)

    report = CohortReport.new(@case_study)
    by_name = report.reach.index_by { |row| row.contact.full_name }

    assert_in_delta 1.0, by_name["Dana Whitfield"].share, 0.001
    assert_in_delta 0.5, by_name["Priya Raghunathan"].share, 0.001
  end

  test "documents earned counts distinct documents across a student's runs" do
    enrollment = enroll("Lena Ahmed")
    conversation = interview(enrollment, @dana)
    message = conversation.messages.where(from_contact: true).first
    DocumentShare.create!(message: message, document: @document)

    report = CohortReport.new(@case_study)

    assert_equal 1, report.students.first.documents_earned
  end

  test "a student's runs are collapsed into one row" do
    user = User.create!(full_name: "Sasha Everly", email: "sasha@example.test", status: 2)
    first = Enrollment.create!(user: user, case_study: @case_study)
    second = Enrollment.create!(user: user, case_study: @case_study)
    interview(first, @dana, messages: 2)
    interview(second, @dana, messages: 1)

    report = CohortReport.new(@case_study)

    assert_equal 1, report.students.size
    assert_equal 2, report.students.first.run_count
    # Effort is cumulative across runs; the point of re-running is trying again.
    assert_equal 3, report.students.first.messages_sent
  end

  test "meeting a contact in any run counts for the student" do
    user = User.create!(full_name: "Sasha Everly", email: "sasha2@example.test", status: 2)
    first = Enrollment.create!(user: user, case_study: @case_study)
    Enrollment.create!(user: user, case_study: @case_study)
    Introduction.create!(enrollment: first, contact: @priya, introducing_contact: @dana)

    report = CohortReport.new(@case_study)

    assert_equal 2, report.students.first.contacts_met
  end

  test "medians are computed across students, not runs" do
    a = enroll("A Student")
    b = enroll("B Student")
    enroll("C Student")
    interview(a, @dana, messages: 10)
    interview(b, @dana, messages: 4)

    report = CohortReport.new(@case_study)

    assert_equal 3, report.students.size
    assert_equal 4, report.median_messages_sent
  end
end
