require "test_helper"

class ConversationPolicyTest < ActiveSupport::TestCase
  test "allows a learner to send only in their own open attempt" do
    learner = create_user(full_name: "Lee Learner")
    conversation = start_learner_conversation(learner:)

    assert ConversationPolicy.new(learner, conversation).show?
    assert ConversationPolicy.new(learner, conversation).send?
    refute ConversationPolicy.new(learner, conversation).inspect?

    Attempt.where(id: conversation.attempt_id).update_all(ended_at: Time.current)

    refute ConversationPolicy.new(learner, conversation).show?
    refute ConversationPolicy.new(learner, conversation).send?
  end

  test "allows a test-drive author to send in their own conversation" do
    author = create_user
    conversation = start_test_drive_conversation(author:)

    assert ConversationPolicy.new(author, conversation).show?
    assert ConversationPolicy.new(author, conversation).send?
    refute ConversationPolicy.new(create_user, conversation).send?
  end

  test "lets a case author inspect a learner conversation without granting send" do
    author = create_user
    conversation = start_learner_conversation(case_author: author)
    policy = ConversationPolicy.new(author, conversation)

    assert policy.show?
    assert policy.inspect?
    refute policy.send?
  end

  test "denies an unrelated user access to a conversation" do
    conversation = start_learner_conversation
    policy = ConversationPolicy.new(create_user, conversation)

    refute policy.show?
    refute policy.inspect?
    refute policy.send?
  end

  test "scopes conversations to current learner work author inspection and test drives" do
    user = create_user
    own_learner_conversation = start_learner_conversation(learner: user)
    inspected_conversation = start_learner_conversation(case_author: user)
    test_drive_conversation = start_test_drive_conversation(author: user)
    excluded_conversation = start_learner_conversation

    assert_equal [own_learner_conversation.id, inspected_conversation.id, test_drive_conversation.id].sort,
      ConversationPolicy::Scope.new(user, Conversation.all).resolve.pluck(:id).sort
    refute_includes ConversationPolicy::Scope.new(user, Conversation.all).resolve.pluck(:id),
      excluded_conversation.id
    assert_empty ConversationPolicy::Scope.new(nil, Conversation.all).resolve
  end

  private

  def start_learner_conversation(learner: create_user(full_name: "Lee Learner"), case_author: create_user)
    case_record = create_case(author: case_author)
    stakeholder = create_stakeholder(case_record:)
    publish_case(case_record)
    attempt = start_attempt(case_record:, user: learner)
    Conversations::StartLearner.call(attempt:, stakeholder_id: stakeholder.id)
  end

  def start_test_drive_conversation(author:)
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
