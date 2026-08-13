module TestDrives
  class Start
    PROVIDERS = %w[openai anthropic].freeze

    def self.call(author:, stakeholder_id:, left:, right: nil)
      new(author:, stakeholder_id:, left:, right:).call
    end

    def initialize(author:, stakeholder_id:, left:, right:)
      @author = author
      @stakeholder_id = stakeholder_id.to_s
      @slot_configurations = {"left" => normalize_configuration(left)}
      @slot_configurations["right"] = normalize_configuration(right) if right
    end

    def call
      validate_slot_configurations!
      case_record = Case
        .joins(:stakeholders)
        .where(author_id: author.id, stakeholders: {id: stakeholder_id})
        .first
      raise StakeholderUnavailable, "stakeholder does not belong to this author" unless case_record

      case_record.with_lock do
        stakeholder = Stakeholder.find_by!(case_id: case_record.id, id: stakeholder_id)
        draft_snapshot = build_draft_snapshot(case_record:)
        test_drive = TestDrive.create!(
          author:,
          stakeholder:,
          configuration_snapshot: draft_snapshot
        )

        slot_configurations.each do |slot, configuration|
          Conversation.create!(
            test_drive:,
            stakeholder:,
            slot:,
            provider: configuration.fetch("provider"),
            model_id: configuration.fetch("model_id"),
            configuration_snapshot: conversation_snapshot(draft_snapshot, configuration)
          )
        end

        test_drive
      end
    end

    private

    attr_reader :author, :stakeholder_id, :slot_configurations

    def normalize_configuration(configuration)
      configuration.to_h.stringify_keys.slice("provider", "model_id", "provider_settings")
    end

    def validate_slot_configurations!
      slot_configurations.each do |slot, configuration|
        provider = configuration.fetch("provider", nil)
        model_id = configuration.fetch("model_id", nil)
        unless PROVIDERS.include?(provider)
          raise InvalidConfiguration, "#{slot} uses an unsupported provider"
        end
        raise InvalidConfiguration, "#{slot} model is blank" if model_id.blank?
        next unless configuration.key?("provider_settings")

        settings = configuration.fetch("provider_settings")
        unless settings.is_a?(Hash)
          raise InvalidConfiguration, "#{slot} provider settings must be an object"
        end
        configuration["provider_settings"] = settings.deep_stringify_keys
      end
    end

    def build_draft_snapshot(case_record:)
      published_shape = Cases::ConfigurationSnapshot.build(case_record:, mode: :draft)
      stakeholder = published_shape.fetch("stakeholders").fetch(stakeholder_id)
      bundles = published_shape.fetch("bundles").select do |_id, bundle|
        bundle.fetch("stakeholder_id") == stakeholder_id
      end
      referrals = published_shape.fetch("referrals").select do |referral|
        referral.fetch("source_stakeholder_id") == stakeholder_id
      end
      document_ids = bundles.values.flat_map { |bundle| bundle.fetch("document_ids") }.uniq

      snapshot = {
        "schema_version" => published_shape.fetch("schema_version"),
        "case" => published_shape.fetch("case").slice("id", "title"),
        "stakeholder" => stakeholder,
        "referrals" => referrals,
        "referral_targets" => referral_targets(published_shape, referrals),
        "documents" => published_shape.fetch("documents").slice(*document_ids),
        "bundles" => bundles
      }
      if stakeholder.fetch("knows_case_background")
        snapshot.fetch("case")["background"] = published_shape.dig("case", "background")
      end
      snapshot
    end

    def referral_targets(published_shape, referrals)
      target_ids = referrals.pluck("target_stakeholder_id")
      published_shape.fetch("stakeholders").slice(*target_ids).transform_values do |target|
        target.slice("id", "name", "role_title", "description")
      end
    end

    def conversation_snapshot(draft_snapshot, configuration)
      draft_snapshot.deep_dup.tap do |snapshot|
        snapshot.fetch("stakeholder").merge!(configuration)
      end
    end
  end
end
