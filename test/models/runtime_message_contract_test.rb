require "test_helper"

class RuntimeMessageContractTest < ActiveSupport::TestCase
  test "requires user and tool messages to be complete" do
    conversation = learner_conversation

    user_message = conversation.messages.new(position: 1, role: "user", status: "pending")
    tool_message = conversation.messages.new(
      position: 2,
      role: "tool",
      status: "pending",
      tool_name: "introduce_stakeholder",
      tool_call_id: "call-1",
      tool_result: {}
    )

    refute user_message.save
    refute tool_message.save
    assert_includes user_message.errors.details[:status], error: :must_be_complete
    assert_includes tool_message.errors.details[:status], error: :must_be_complete
  end

  test "requires tool metadata only on tool messages" do
    conversation = learner_conversation
    missing_metadata = conversation.messages.new(position: 1, role: "tool", status: "complete")
    valid_tool = conversation.messages.new(
      position: 2,
      role: "tool",
      status: "complete",
      tool_name: "release_documents",
      tool_call_id: "call-1",
      tool_result: {"released" => true}
    )
    user_with_metadata = conversation.messages.new(
      position: 3,
      role: "user",
      status: "complete",
      tool_name: "release_documents"
    )

    refute missing_metadata.save
    assert valid_tool.save
    refute user_with_metadata.save
    assert_includes missing_metadata.errors.details[:base], error: :invalid_tool_metadata
    assert_includes user_with_metadata.errors.details[:base], error: :invalid_tool_metadata
  end

  test "allows multiple model runs only for an assistant message" do
    conversation = learner_conversation
    assistant = conversation.messages.create!(position: 1, role: "assistant", status: "complete")
    user = conversation.messages.create!(position: 2, role: "user", status: "complete")
    attributes = {
      provider: "openai",
      model_id: "gpt-5-mini",
      status: "complete",
      input_snapshot: {}
    }

    assert assistant.model_runs.create!(attributes)
    assert assistant.model_runs.create!(attributes.merge(provider_response_id: "response-2"))
    invalid_run = user.model_runs.new(attributes)
    refute invalid_run.save
    assert_includes invalid_run.errors.details[:message], error: :not_assistant
  end

  test "database constraints reject malformed provider writes" do
    conversation = learner_conversation

    assert_raises(ActiveRecord::StatementInvalid) do
      ActiveRecord::Base.transaction(requires_new: true) do
        Message.insert!({
          conversation_id: conversation.id,
          position: 1,
          role: "user",
          status: "pending",
          content: "",
          created_at: Time.current,
          updated_at: Time.current
        })
      end
    end

    assert_raises(ActiveRecord::StatementInvalid) do
      ActiveRecord::Base.transaction(requires_new: true) do
        Message.insert!({
          conversation_id: conversation.id,
          position: 2,
          role: "tool",
          status: "complete",
          content: "",
          created_at: Time.current,
          updated_at: Time.current
        })
      end
    end
  end

  test "database permits a provider tool call only once per conversation" do
    conversation = learner_conversation
    attributes = {
      conversation_id: conversation.id,
      role: "tool",
      status: "complete",
      content: "",
      tool_name: "release_documents",
      tool_call_id: "call-1",
      tool_result: {},
      created_at: Time.current,
      updated_at: Time.current
    }
    Message.insert!(attributes.merge(position: 1))

    assert_raises(ActiveRecord::RecordNotUnique) do
      Message.insert!(attributes.merge(position: 2))
    end
  end

  private

  def learner_conversation
    records = create_publishable_case
    publish_case(records[:case])
    attempt = start_attempt(case_record: records[:case])
    Conversations::StartLearner.call(attempt:, stakeholder_id: records[:stakeholder].id)
  end
end
