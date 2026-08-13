module Conversations
  class StartLearner
    def self.call(attempt:, stakeholder_id:)
      new(attempt:, stakeholder_id:).call
    end

    def initialize(attempt:, stakeholder_id:)
      @attempt = attempt
      @stakeholder_id = stakeholder_id.to_s
    end

    def call
      attempt.with_lock do
        attempt.reload
        raise ClosedAttempt, "cannot start a conversation in a closed attempt" if attempt.ended_at?

        stakeholder = attempt.configuration_snapshot.fetch("stakeholders", {}).fetch(stakeholder_id, nil)
        raise StakeholderUnavailable, "stakeholder is not part of this attempt" unless stakeholder

        introduced = Introduction.where(
          attempt_id: attempt.id,
          target_stakeholder_id: stakeholder_id
        ).exists?
        unless stakeholder.fetch("available_at_start") || introduced
          raise StakeholderUnavailable, "stakeholder has not been introduced"
        end

        Conversation.find_or_create_by!(attempt_id: attempt.id, stakeholder_id:) do |conversation|
          conversation.provider = stakeholder.fetch("provider")
          conversation.model_id = stakeholder.fetch("model_id")
          conversation.configuration_snapshot = conversation_snapshot(stakeholder)
        end
      end
    end

    private

    attr_reader :attempt, :stakeholder_id

    def conversation_snapshot(stakeholder)
      published = attempt.configuration_snapshot
      bundles = published.fetch("bundles", {}).select do |_id, bundle|
        bundle.fetch("stakeholder_id") == stakeholder_id
      end
      referrals = published.fetch("referrals").select do |referral|
        referral.fetch("source_stakeholder_id") == stakeholder_id
      end
      document_ids = bundles.values.flat_map { |bundle| bundle.fetch("document_ids") }.uniq

      snapshot = {
        "schema_version" => published.fetch("schema_version"),
        "case" => published.fetch("case").slice("id", "title"),
        "stakeholder" => stakeholder.deep_dup,
        "referrals" => referrals,
        "referral_targets" => referral_targets(published, referrals),
        "documents" => published.fetch("documents").slice(*document_ids),
        "bundles" => bundles
      }
      if stakeholder.fetch("knows_case_background")
        snapshot.fetch("case")["background"] = published.dig("case", "background")
      end
      snapshot
    end

    def referral_targets(published, referrals)
      target_ids = referrals.pluck("target_stakeholder_id")
      published.fetch("stakeholders").slice(*target_ids).transform_values do |target|
        target.slice("id", "name", "role_title", "description")
      end
    end
  end
end
