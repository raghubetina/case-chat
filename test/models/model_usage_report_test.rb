require "test_helper"
require_relative "domain_test_helper"

# The screen exists to answer two questions: what does a run of this case cost,
# and which stakeholder is expensive. Both are wrong if rehearsals and students'
# replies are added together.
class ModelUsageReportTest < ActiveSupport::TestCase
  include DomainTestHelper

  setup do
    @case_study = build_case_study
    @dana = build_contact(case_study: @case_study, full_name: "Dana Whitfield")
    @priya = build_contact(case_study: @case_study, full_name: "Priya Raghunathan")
  end

  def record(contact:, model: "claude-opus-5", message: nil, input: 1000, output: 200, cache_read: 0)
    ModelCall.record(
      contact: contact, message: message, provider: "anthropic", model: model,
      reply: Responder::Reply.new(
        text: "Because the plants changed over more often.",
        usage: Responder::Usage.new(
          input_tokens: input, output_tokens: output,
          cache_read_tokens: cache_read, cache_write_tokens: 0
        )
      )
    )
  end

  def student_message
    enrollment = build_enrollment(case_study: @case_study)
    conversation = Conversation.create!(enrollment: enrollment, contact: @dana)
    Message.create!(conversation: conversation, body: "Why did margin fall?",
      sent_at: Time.current, from_contact: true)
  end

  test "a case nobody has run reports nothing rather than raising" do
    report = ModelUsageReport.new(@case_study)

    assert_not report.any_calls?
    assert_empty report.rows
    assert_equal 0, report.grand_totals.tokens
    assert_nil report.tokens_per_run
  end

  test "keeps rehearsals out of the reply total" do
    record(contact: @dana, message: student_message, input: 1000, output: 100)
    record(contact: @dana, input: 5000, output: 500)

    report = ModelUsageReport.new(@case_study)

    assert_equal 1100, report.reply_totals.tokens
    assert_equal 5500, report.rehearsal_totals.tokens
    assert_equal 6600, report.grand_totals.tokens, "the invoice is still the sum of both"
  end

  # An author who rehearsed forty times would otherwise see a per-run forecast
  # forty times the truth.
  test "the per-run figure counts students' replies only" do
    record(contact: @dana, message: student_message, input: 1000, output: 0)
    record(contact: @dana, input: 90_000, output: 0)

    assert_equal 1000, ModelUsageReport.new(@case_study).tokens_per_run
  end

  test "a restart counts as a second run" do
    message = student_message
    record(contact: @dana, message: message, input: 1000, output: 0)
    build_enrollment(case_study: @case_study, user: message.conversation.enrollment.user)

    assert_equal 500, ModelUsageReport.new(@case_study).tokens_per_run
  end

  test "orders stakeholders by what they spent, heaviest first" do
    record(contact: @dana, input: 100, output: 0)
    record(contact: @priya, input: 9000, output: 0)

    assert_equal [@priya, @dana], ModelUsageReport.new(@case_study).rows.map(&:contact)
  end

  test "a stakeholder with no calls is left out entirely" do
    record(contact: @dana, input: 100, output: 0)

    assert_equal [@dana], ModelUsageReport.new(@case_study).rows.map(&:contact)
  end

  test "prices a row from the model its calls actually ran under" do
    record(contact: @dana, model: "claude-opus-5", input: 1_000_000, output: 0)

    assert_in_delta 5.00, ModelUsageReport.new(@case_study).cost, 0.001
  end

  # A contact's model is editable, and old calls keep the id they ran under, so
  # one row can legitimately span two models with different rates.
  test "prices a stakeholder whose model changed part way through" do
    record(contact: @dana, model: "claude-opus-5", input: 1_000_000, output: 0)
    record(contact: @dana, model: "claude-sonnet-5", input: 1_000_000, output: 0)

    # Opus at $5 plus Sonnet at $2. Sonnet was $3 until Anthropic made its
    # introductory rate permanent, which is the change that motivated pricing
    # each call from the rate it was billed at.
    assert_in_delta 7.00, ModelUsageReport.new(@case_study).cost, 0.001
  end

  # A partial sum wearing the word "total" is the failure the blank prices exist
  # to prevent.
  test "reports no total when any call ran on a model with no price" do
    record(contact: @dana, model: "claude-opus-5", input: 1_000_000, output: 0)
    record(contact: @priya, model: "gpt-5.6-retired", input: 1_000_000, output: 0)

    report = ModelUsageReport.new(@case_study)

    assert_nil report.cost
    assert_in_delta 5.00, report.rows.find { |row| row.contact == @dana }.cost, 0.001,
      "the priced stakeholder still reports their own figure"
  end

  test "cache hit rate is the share of input the cache answered" do
    record(contact: @dana, input: 1000, output: 0, cache_read: 900)

    assert_in_delta 0.9, ModelUsageReport.new(@case_study).rows.first.total.cache_hit_rate, 0.001
  end

  test "a stakeholder who was sent nothing does not divide by zero" do
    record(contact: @dana, input: 0, output: 0, cache_read: 0)

    assert_equal 0.0, ModelUsageReport.new(@case_study).rows.first.total.cache_hit_rate
  end

  # The rollup is one grouped query and a fold, so adding stakeholders must not
  # add queries.
  test "the rollup does not issue a query per stakeholder" do
    record(contact: @dana, input: 100, output: 0)
    record(contact: @priya, input: 100, output: 0)
    baseline = count_queries { ModelUsageReport.new(@case_study).rows }

    3.times { |i| record(contact: build_contact(case_study: @case_study, full_name: "Extra #{i}"), input: 100, output: 0) }

    assert_equal baseline, count_queries { ModelUsageReport.new(@case_study).rows }
  end

  def count_queries(&block)
    count = 0
    counter = ->(*, payload) { count += 1 unless payload[:name] == "SCHEMA" || payload[:cached] }
    ActiveSupport::Notifications.subscribed(counter, "sql.active_record", &block)
    count
  end
end
