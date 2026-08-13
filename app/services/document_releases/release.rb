module DocumentReleases
  class Release
    def self.call(attempt:, message:, document_bundle_id:)
      new(attempt:, message:, document_bundle_id:).call
    end

    def initialize(attempt:, message:, document_bundle_id:)
      @attempt = attempt
      @message = message
      @document_bundle_id = document_bundle_id.to_s
    end

    def call
      attempt.with_lock do
        attempt.reload
        raise ClosedAttempt, "cannot release a document in a closed attempt" if attempt.ended_at?

        source_stakeholder_id = validated_source_stakeholder_id
        bundle = attempt.configuration_snapshot.fetch("bundles", {}).fetch(document_bundle_id, nil)
        unless bundle && bundle.fetch("stakeholder_id") == source_stakeholder_id
          raise NotAllowed, "bundle is not available to this stakeholder in the pinned configuration"
        end

        DocumentRelease.find_or_create_by!(
          attempt_id: attempt.id,
          document_bundle_id:
        ) do |release|
          release.message = message
        end
      end
    end

    private

    attr_reader :attempt, :message, :document_bundle_id

    def validated_source_stakeholder_id
      role, status, message_attempt_id, source_stakeholder_id = Message
        .joins(:conversation)
        .where(id: message.id)
        .pick(:role, :status, "conversations.attempt_id", "conversations.stakeholder_id")

      unless role == "assistant" && status == "complete" && message_attempt_id == attempt.id
        raise InvalidMessage, "release must come from a completed assistant message in this attempt"
      end

      source_stakeholder_id
    end
  end
end
