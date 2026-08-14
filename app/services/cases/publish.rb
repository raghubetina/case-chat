module Cases
  class Publish
    Result = Data.define(:snapshot, :outcome) do
      def publication_changed?
        outcome == :published
      end
    end

    def self.call(case_record:, at: Time.current)
      new(case_record:, at:).call
    end

    def initialize(case_record:, at:)
      @case_record = case_record
      @at = at
    end

    def call
      case_record.with_lock do
        readiness = PublicationReadiness.call(case_record:)
        raise InvalidConfiguration.new(readiness) unless readiness.ready?

        if readiness.publish_needed?
          lock_graph_members!(readiness.snapshot)
          lock_attachments!(readiness.snapshot)
          case_record.update!(
            status: "published",
            published_configuration: readiness.snapshot,
            published_at: at
          )
          Result.new(snapshot: readiness.snapshot, outcome: :published)
        else
          Result.new(snapshot: readiness.snapshot, outcome: :current)
        end
      end
    end

    private

    attr_reader :case_record, :at

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
