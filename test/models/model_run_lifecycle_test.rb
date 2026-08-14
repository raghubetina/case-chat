require "test_helper"

class ModelRunLifecycleTest < ActiveSupport::TestCase
  test "pins the message, provider, model, and request input after creation" do
    run = create_model_run
    original = run.attributes.slice("message_id", "provider", "model_id", "input_snapshot")

    refute run.update(
      message: create_assistant_message,
      provider: "anthropic",
      model_id: "claude-sonnet-4-5",
      input_snapshot: {"changed" => true}
    )

    assert_includes run.errors.details[:base], error: :identity_immutable
    assert_equal original, run.reload.attributes.slice(*original.keys)
  end

  private

  def create_model_run
    ModelRun.create!(
      message: create_assistant_message,
      provider: "openai",
      model_id: "gpt-5-mini",
      status: "pending",
      input_snapshot: {"input" => "Question"}
    )
  end

  def create_assistant_message
    author = create_user
    case_record = create_case(author:)
    stakeholder = create_stakeholder(case_record:)
    test_drive = TestDrives::Start.call(
      author:,
      stakeholder_id: stakeholder.id,
      left: {provider: "openai", model_id: "gpt-5-mini"}
    )
    conversation = Conversation.find_by!(test_drive_id: test_drive.id, slot: "left")
    Message.create!(conversation:, position: 1, role: "assistant", status: "pending")
  end
end
