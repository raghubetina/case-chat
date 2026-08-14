require "test_helper"

class GenerateStakeholderReplyJobTest < ActiveJob::TestCase
  test "routes generation to the AI lane and delegates by persisted run ID" do
    run_id = SecureRandom.uuid
    received = []

    fake_generate = Class.new do
      define_singleton_method(:call) { |**arguments| received << arguments }
    end

    stub_const(ConversationRuns, :Generate, fake_generate) do
      GenerateStakeholderReplyJob.perform_now(run_id)
    end

    assert_equal "ai", GenerateStakeholderReplyJob.queue_name
    assert_equal [{model_run_id: run_id}], received
  end
end
