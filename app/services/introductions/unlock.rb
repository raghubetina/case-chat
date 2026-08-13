module Introductions
  class Unlock
    def self.call(attempt:, message:, stakeholder_id:)
      new(attempt:, message:, stakeholder_id:).call
    end

    def initialize(attempt:, message:, stakeholder_id:)
      @attempt = attempt
      @message = message
      @stakeholder_id = stakeholder_id.to_s
    end

    def call
      attempt.with_lock do
        attempt.reload
        raise ClosedAttempt, "cannot unlock an introduction in a closed attempt" if attempt.ended_at?

        source_stakeholder_id = validated_source_stakeholder_id
        allowed = attempt.configuration_snapshot.fetch("referrals").any? do |referral|
          referral.fetch("source_stakeholder_id") == source_stakeholder_id &&
            referral.fetch("target_stakeholder_id") == stakeholder_id
        end
        unless allowed && attempt.configuration_snapshot.fetch("stakeholders").key?(stakeholder_id)
          raise NotAllowed, "introduction is outside the pinned referral graph"
        end

        Introduction.find_or_create_by!(attempt_id: attempt.id, target_stakeholder_id: stakeholder_id) do |introduction|
          introduction.message = message
        end
      end
    end

    private

    attr_reader :attempt, :message, :stakeholder_id

    def validated_source_stakeholder_id
      role, status, message_attempt_id, source_stakeholder_id = Message
        .joins(:conversation)
        .where(id: message.id)
        .pick(:role, :status, "conversations.attempt_id", "conversations.stakeholder_id")

      unless role == "assistant" && status == "complete" && message_attempt_id == attempt.id
        raise InvalidMessage, "introduction must come from a completed assistant message in this attempt"
      end

      source_stakeholder_id
    end
  end
end
