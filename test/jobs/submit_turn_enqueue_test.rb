require "test_helper"

class SubmitTurnEnqueueTest < ActiveJob::TestCase
  test "hands the persisted run ID to the real generation job" do
    conversation = create_test_drive_conversation
    original_setting = GenerateStakeholderReplyJob.enqueue_after_transaction_commit
    GenerateStakeholderReplyJob.enqueue_after_transaction_commit = false

    result = Conversations::SubmitTurn.call(
      conversation:,
      content: "What happened?"
    )

    assert_predicate result.model_run, :persisted?
    assert_enqueued_with(
      job: GenerateStakeholderReplyJob,
      args: [result.model_run.id],
      queue: "ai"
    )
  ensure
    GenerateStakeholderReplyJob.enqueue_after_transaction_commit = original_setting
  end

  private

  def create_test_drive_conversation
    author = create_user
    case_record = create_case(author:)
    stakeholder = create_stakeholder(case_record:)
    test_drive = TestDrives::Start.call(
      author:,
      stakeholder_id: stakeholder.id,
      left: {provider: "openai", model_id: "gpt-5-mini"}
    )
    Conversation.find_by!(test_drive_id: test_drive.id, slot: "left")
  end
end
