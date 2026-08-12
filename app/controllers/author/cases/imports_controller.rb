module Author
  module Cases
    # Drafting a case from documents the instructor already has. The draft is
    # proposed; nothing exists until the author accepts it.
    class ImportsController < Author::BaseController
      def new
        @case_study = authored_case!
        @documents = Document.where(case_study_id: @case_study.id).order(:file_name)
        @draft = stored_draft&.draft
      end

      def create
        @case_study = authored_case!
        @documents = Document.where(case_study_id: @case_study.id).order(:file_name)

        draft = stored_draft&.draft if params[:accept].present?

        if draft
          result = CaseImport.new(@case_study, draft).apply!
          clear_draft
          redirect_to edit_author_case_path(@case_study), notice: accepted_notice(result)
        else
          draft_and_redisplay
        end
      end

      private

      def draft_and_redisplay
        if @documents.none? { |document| document.file.attached? }
          return redirect_to author_case_documents_path(@case_study), alert: t("author.imports.no_documents")
        end

        @draft = CaseDrafter.current.draft(documents: @documents, hint: params[:hint].presence)
        store_draft(@draft)
        render :new
      rescue CaseDrafter::Error => e
        Rails.logger.error("Case draft failed for #{@case_study.id}: #{e.message}")
        redirect_to new_author_case_import_path(@case_study), alert: t("author.imports.failed")
      end

      def store_draft(draft) = CaseDraft.store(@case_study, draft)

      def stored_draft
        @stored_draft ||= CaseDraft.find_by(case_study_id: @case_study.id)
      end

      # Accepting consumes the proposal, so a resubmitted accept cannot apply
      # the same draft twice.
      def clear_draft = stored_draft&.destroy!

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
