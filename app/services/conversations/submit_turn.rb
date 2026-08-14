require "digest"

module Conversations
  class SubmitTurn
    MAX_INPUT_LENGTH = 4_000
    MAX_OUTPUT_TOKENS = Integer(ENV.fetch("STAKEHOLDER_MAX_OUTPUT_TOKENS", "800"), 10)
    Result = Data.define(:user_message, :assistant_message, :model_run)

    def self.call(
      conversation:,
      content:,
      enqueue: ->(model_run_id) { GenerateStakeholderReplyJob.perform_later(model_run_id) }
    )
      new(conversation:, content:, enqueue:).call
    end

    def initialize(conversation:, content:, enqueue:)
      @conversation = conversation
      @content = normalize_content(content)
      @enqueue = enqueue
    end

    def call
      conversation.with_lock do
        conversation.reload
        with_open_attempt_lock { persist_turn }
      end
    end

    private

    attr_reader :conversation, :content, :enqueue

    def normalize_content(value)
      unless value.is_a?(String) && value.strip.present?
        raise InvalidTurn, "question must be present"
      end

      normalized = value.strip
      if normalized.length > MAX_INPUT_LENGTH
        raise InvalidTurn, "question must be at most #{MAX_INPUT_LENGTH} characters"
      end
      normalized
    end

    def validate_no_reply_in_progress!
      in_flight = Message.where(
        conversation_id: conversation.id,
        role: "assistant",
        status: %w[pending streaming]
      ).exists?
      raise ReplyInProgress, "wait for the current reply to finish" if in_flight
    end

    def with_open_attempt_lock
      return yield unless conversation.attempt_id

      attempt = Attempt.find(conversation.attempt_id)
      attempt.with_lock do
        attempt.reload
        raise ClosedAttempt, "cannot add a turn to a closed attempt" if attempt.ended_at?

        yield
      end
    end

    def persist_turn
      validate_no_reply_in_progress!
      prompt = StakeholderPrompts::Compose.call(
        configuration_snapshot: conversation.configuration_snapshot
      )
      request_snapshot = input_snapshot(prompt:)
      ConversationRuns::ProviderRequest.call(
        provider: conversation.provider,
        model_id: conversation.model_id,
        input_snapshot: request_snapshot
      )
      next_position = Message.where(conversation_id: conversation.id).maximum(:position).to_i + 1

      user_message = Message.create!(
        conversation_id: conversation.id,
        position: next_position,
        role: "user",
        status: "complete",
        content:
      )
      assistant_message = Message.create!(
        conversation_id: conversation.id,
        position: next_position + 1,
        role: "assistant",
        status: "pending",
        content: ""
      )
      model_run = ModelRun.create!(
        message_id: assistant_message.id,
        provider: conversation.provider,
        model_id: conversation.model_id,
        status: "pending",
        input_snapshot: request_snapshot
      )

      enqueue.call(model_run.id)
      Result.new(user_message:, assistant_message:, model_run:)
    end

    def input_snapshot(prompt:)
      {
        "schema_version" => 1,
        "prompt" => {
          "version" => prompt.version,
          "system_prompt" => prompt.system_prompt
        },
        "history" => completed_history,
        "input" => content,
        "cursor" => usable_provider_cursor,
        "max_output_tokens" => MAX_OUTPUT_TOKENS,
        "cache_key" => cache_key(prompt),
        "tools" => []
      }
    end

    def completed_history
      Message
        .where(conversation_id: conversation.id, role: %w[user assistant], status: "complete")
        .order(:position)
        .pluck(:role, :content)
        .map { |role, content| {"role" => role, "content" => content} }
    end

    def cache_key(prompt)
      return unless conversation.provider == "openai"

      Digest::SHA256.hexdigest("#{prompt.version}\0#{prompt.system_prompt}")
    end

    def usable_provider_cursor
      return unless conversation.provider_cursor && conversation.provider_cursor_position

      completed_after_cursor = Message.where(
        conversation_id: conversation.id,
        role: %w[user assistant],
        status: "complete"
      ).where("position > ?", conversation.provider_cursor_position).exists?
      conversation.provider_cursor unless completed_after_cursor
    end
  end
end
