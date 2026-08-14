module Author
  class CasesController < AuthenticatedController
    before_action :set_case, only: %i[edit update publish]
    before_action :authorize_case_update, only: %i[edit update]

    def index
      authored_cases = policy_scope(Case)
        .where(author_id: current_user.id)
        .order(updated_at: :desc, id: :desc)
      @pagy, @cases = pagy(:offset, authored_cases)
    end

    def new
      authorize Case, :create?
      @case = current_user.authored_cases.build
    end

    def create
      authorize Case, :create?
      @case = Cases::CreateDraft.call(author: current_user, attributes: case_params)

      if @case.persisted?
        redirect_to edit_author_case_path(@case), notice: t("author.cases.flash.created")
      else
        render :new, status: :unprocessable_content
      end
    end

    def edit
      set_publication_readiness
    end

    def update
      if publish_after_save?
        update_and_publish
      else
        update_draft
      end
    end

    def publish
      authorize @case, :publish?
      result = Cases::Publish.call(case_record: @case)
      flash_key = result.publication_changed? ? "published" : "current"

      redirect_to edit_author_case_path(@case),
        notice: t("author.cases.publication.flash.#{flash_key}")
    rescue Cases::InvalidConfiguration => error
      @publication_readiness = error.readiness
      render :edit, status: :unprocessable_content
    end

    private

    def update_draft
      @case = Cases::UpdateDraft.call(case_record: @case, attributes: case_params)

      if @case.errors.empty?
        redirect_to edit_author_case_path(@case), notice: t("author.cases.flash.updated")
      else
        render :edit, status: :unprocessable_content
      end
    end

    def update_and_publish
      authorize @case, :publish?
      result = Cases::UpdateAndPublish.call(case_record: @case, attributes: case_params)
      @case = result.case_record

      if @case.errors.any?
        render :edit, status: :unprocessable_content
      elsif result.publication_result
        flash_key = result.publication_result.publication_changed? ? "published" : "current"
        redirect_to edit_author_case_path(@case),
          notice: t("author.cases.publication.flash.#{flash_key}")
      else
        @publication_readiness = result.readiness
        flash.now[:alert] = t("author.cases.publication.flash.incomplete")
        render :edit, status: :unprocessable_content
      end
    end

    def set_case
      @case = current_user.authored_cases.find(params[:id])
    end

    def authorize_case_update
      authorize @case, :update?
    end

    def set_publication_readiness
      @publication_readiness = Cases::PublicationReadiness.call(case_record: @case)
    end

    def case_params
      params.expect(case: Case::DRAFT_EDITABLE_ATTRIBUTES)
    end

    def publish_after_save?
      params[:publish_after_save] == "1"
    end
  end
end
