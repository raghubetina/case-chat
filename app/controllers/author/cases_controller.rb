module Author
  class CasesController < AuthenticatedController
    before_action :set_case, only: %i[edit update]

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
    end

    def update
      @case = Cases::UpdateDraft.call(case_record: @case, attributes: case_params)

      if @case.errors.empty?
        redirect_to edit_author_case_path(@case), notice: t("author.cases.flash.updated")
      else
        render :edit, status: :unprocessable_content
      end
    end

    private

    def set_case
      @case = current_user.authored_cases.find(params[:id])
      authorize @case, :update?
    end

    def case_params
      params.expect(case: Case::DRAFT_EDITABLE_ATTRIBUTES)
    end
  end
end
