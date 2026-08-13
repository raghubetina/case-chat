module Cases
  class Publish
    def self.call(case_record:, at: Time.current)
      new(case_record:, at:).call
    end

    def initialize(case_record:, at:)
      @case_record = case_record
      @at = at
    end

    def call
      case_record.with_lock do
        case_record.reload
        snapshot = ConfigurationSnapshot.build(case_record:, mode: :publication)
        validate!(snapshot)
        lock_graph_members!(snapshot)
        lock_attachments!(snapshot)
        case_record.update!(
          status: "published",
          published_configuration: snapshot,
          published_at: at
        )
        snapshot
      end
    end

    private

    attr_reader :case_record, :at

    def validate!(snapshot)
      problems = []
      problems << "background is blank" if snapshot.dig("case", "background").blank?
      problems << "assignment is blank" if snapshot.dig("case", "assignment").blank?
      problems << "at least one stakeholder is required" if snapshot.fetch("stakeholders").empty?
      unless snapshot.fetch("stakeholders").any? { |_id, stakeholder| stakeholder.fetch("available_at_start") }
        problems << "at least one stakeholder must be available at the start"
      end

      snapshot.fetch("stakeholders").each_value do |stakeholder|
        unless %w[openai anthropic].include?(stakeholder.fetch("provider"))
          problems << "#{stakeholder.fetch("name")} uses an unsupported provider"
        end
        problems << "#{stakeholder.fetch("name")} has no model" if stakeholder.fetch("model_id").blank?
      end

      snapshot.fetch("referrals").each do |referral|
        source_id = referral.fetch("source_stakeholder_id")
        target_id = referral.fetch("target_stakeholder_id")
        unless snapshot.fetch("stakeholders").key?(source_id) && snapshot.fetch("stakeholders").key?(target_id)
          problems << "referral #{referral.fetch("id")} crosses the case boundary"
        end
      end

      snapshot.fetch("bundles").each_value do |bundle|
        problems << "#{bundle.fetch("name")} has no documents" if bundle.fetch("document_ids").empty?
        problems << "#{bundle.fetch("name")} has no stakeholder" unless snapshot.fetch("stakeholders").key?(bundle.fetch("stakeholder_id"))
        if bundle.fetch("document_ids").any? { |document_id| !snapshot.fetch("documents").key?(document_id) }
          problems << "#{bundle.fetch("name")} contains a document from another case"
        end
      end

      raise InvalidConfiguration, problems if problems.any?
    end

    def lock_attachments!(snapshot)
      CaseDocument.with_attached_file.where(id: snapshot.fetch("documents").keys).find_each do |document|
        CaseDocumentPublicationLock.find_or_create_by!(case_document_id: document.id) do |lock|
          lock.active_storage_attachment_id = document.file.attachment&.id
        end
        document.update!(attachment_locked_at: at) unless document.attachment_locked_at?
      end
    end

    def lock_graph_members!(snapshot)
      Stakeholder
        .where(id: snapshot.fetch("stakeholders").keys, publication_locked_at: nil)
        .update_all(publication_locked_at: at, updated_at: at)
      DocumentBundle
        .where(id: snapshot.fetch("bundles").keys, publication_locked_at: nil)
        .update_all(publication_locked_at: at, updated_at: at)
    end
  end
end
