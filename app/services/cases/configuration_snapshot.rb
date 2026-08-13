module Cases
  class ConfigurationSnapshot
    MODES = %i[publication draft].freeze

    def self.build(case_record:, mode: :publication)
      new(case_record:, mode:).build
    end

    def initialize(case_record:, mode:)
      raise ArgumentError, "unknown snapshot mode: #{mode}" unless MODES.include?(mode)

      @case_record = case_record
      @mode = mode
    end

    def build
      {
        "schema_version" => 1,
        "case" => case_snapshot,
        "stakeholders" => stakeholder_snapshots,
        "referrals" => referral_snapshots,
        "documents" => document_snapshots,
        "bundles" => bundle_snapshots
      }
    end

    private

    attr_reader :case_record, :mode

    def case_snapshot
      case_record.attributes.slice("id", "title", "background", "assignment")
    end

    def stakeholder_snapshots
      stakeholders.to_h do |stakeholder|
        [
          stakeholder.id,
          stakeholder.attributes.slice(
            "id", "name", "role_title", "description", "instructions",
            "knows_case_background", "available_at_start", "provider", "model_id",
            "provider_settings"
          )
        ]
      end
    end

    def referral_snapshots
      Referral
        .where(
          source_stakeholder_id: stakeholder_ids,
          target_stakeholder_id: stakeholder_ids
        )
        .order(:id)
        .map do |referral|
          referral.attributes.slice(
            "id", "source_stakeholder_id", "target_stakeholder_id", "guidance"
          )
        end
    end

    def document_snapshots
      CaseDocument.with_attached_file
        .where(case_id: case_record.id, id: published_document_ids)
        .order(:id)
        .to_h do |document|
        snapshot = document.attributes.slice(
          "id", "title", "description", "learner_text", "available_at_start"
        )
        snapshot["attachment"] = attachment_snapshot(document)
        [document.id, snapshot]
      end
    end

    def attachment_snapshot(document)
      return unless document.file.attached?

      document.file.blob.attributes.slice(
        "id", "filename", "content_type", "byte_size", "checksum"
      ).transform_keys("id" => "blob_id")
    end

    def bundle_snapshots
      bundles.to_h do |bundle|
        snapshot = bundle.attributes.slice("id", "stakeholder_id", "name", "guidance")
        snapshot["document_ids"] = item_ids_by_bundle.fetch(bundle.id, []).map(&:second)
        [bundle.id, snapshot]
      end
    end

    def bundles
      @bundles ||= begin
        relation = DocumentBundle.where(stakeholder_id: stakeholder_ids)
        relation = relation.where(included_in_publication: true) if mode == :publication
        relation.order(:id)
      end
    end

    def stakeholders
      @stakeholders ||= begin
        relation = Stakeholder.where(case_id: case_record.id)
        relation = relation.where(included_in_publication: true) if mode == :publication
        relation.order(:id)
      end
    end

    def stakeholder_ids
      @stakeholder_ids ||= stakeholders.pluck(:id)
    end

    def item_ids_by_bundle
      @item_ids_by_bundle ||= DocumentBundleItem
        .where(document_bundle_id: bundles.select(:id))
        .order(:document_bundle_id, :position, :id)
        .pluck(:document_bundle_id, :case_document_id)
        .group_by(&:first)
    end

    def published_document_ids
      initial_ids = CaseDocument.where(case_id: case_record.id, available_at_start: true).pluck(:id)
      bundled_ids = item_ids_by_bundle.values.flatten(1).map(&:second)

      (initial_ids + bundled_ids).uniq
    end
  end
end
