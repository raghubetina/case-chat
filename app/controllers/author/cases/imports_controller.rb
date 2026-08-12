module Author
  module Cases
    # Drafting a case from documents the instructor already has. The draft is
    # proposed; nothing exists until the author accepts it.
    class ImportsController < Author::BaseController
      def new
        @case_study = authored_case!
        @documents = case_documents
        @case_draft = stored_draft
      end

      def create
        @case_study = authored_case!

        if params[:accept].present?
          accept
        else
          start_draft
        end
      end

      private

      # Reading real case material takes about two minutes, so the author gets
      # a page that waits rather than a request that dies.
      def start_draft
        @documents = case_documents

        if @documents.none? { |document| document.file.attached? }
          return redirect_to author_case_documents_path(@case_study), alert: t("author.imports.no_documents")
        end

        case_draft = CaseDraft.start!(@case_study, hint: params[:hint])
        CaseDraftJob.perform_later(case_draft.id)
        redirect_to new_author_case_import_path(@case_study), notice: t("author.imports.started")
      end

      def accept
        draft = stored_draft&.draft

        if draft.nil?
          return redirect_to new_author_case_import_path(@case_study), alert: t("author.imports.nothing_to_accept")
        end

        result = CaseImport.new(@case_study, draft, case_draft: stored_draft).apply!
        redirect_to edit_author_case_path(@case_study), notice: accepted_notice(result)
      end

      # with_attached_file, because the page asks every document whether it is
      # readable, which is a blob lookup each.
      def case_documents
        Document.where(case_study_id: @case_study.id).with_attached_file.order(:file_name)
      end

      def stored_draft
        @stored_draft ||= CaseDraft.find_by(case_study_id: @case_study.id)
      end

      def accepted_notice(result)
        if result.reachability.complete?
          t("author.imports.accepted", count: result.contacts.size)
        else
          t("author.imports.accepted_with_orphans",
            count: result.contacts.size,
            names: result.reachability.unreachable.map(&:full_name).to_sentence)
        end
      end
    end
  end
end
