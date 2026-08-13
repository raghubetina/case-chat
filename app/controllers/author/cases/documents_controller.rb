module Author
  module Cases
    class DocumentsController < Author::BaseController
      def index
        @case_study = authored_case!
        @documents = Document.where(case_study_id: @case_study.id)
          .with_attached_file.order(given_at_start: :desc, file_name: :asc)
        @document = Document.new(case_study: @case_study)
      end

      def new
        @case_study = authored_case!
        authorize! Document, to: :new?
        @document = Document.new(case_study: @case_study)
      end

      def create
        @case_study = authored_case!
        @document = Document.new(document_params.merge(case_study: @case_study))
        authorize! @document, to: :create?

        if @document.save
          redirect_to author_case_documents_path(@case_study), notice: t("author.documents.added")
        else
          @documents = Document.where(case_study_id: @case_study.id).order(:file_name)
          render :index, status: :unprocessable_content
        end
      end

      def destroy
        @case_study = authored_case!
        document = Document.includes(:case_study).where(case_study_id: @case_study.id).find(params[:id])
        authorize! document, to: :destroy?
        document.destroy!

        redirect_to author_case_documents_path(@case_study), notice: t("author.documents.removed")
      end

      private

      def document_params
        params.expect(document: %i[file_name description file_url given_at_start file])
      end
    end
  end
end
