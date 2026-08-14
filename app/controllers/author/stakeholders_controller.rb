module Author
  class StakeholdersController < AuthenticatedController
    before_action :set_case
    before_action :set_stakeholder, only: %i[edit update]

    def index
      authored_stakeholders = policy_scope(Stakeholder)
        .where(case_id: @case.id)
        .order(:name, :id)
      @pagy, @stakeholders = pagy(:offset, authored_stakeholders)
    end

    def new
      @stakeholder = @case.stakeholders.build
      authorize @stakeholder, :create?
    end

    def create
      authorize @case.stakeholders.build, :create?
      @stakeholder = Stakeholders::CreateDraft.call(
        case_record: @case,
        attributes: stakeholder_params
      )

      if @stakeholder.persisted?
        redirect_to author_case_stakeholders_path(@case),
          notice: t("author.stakeholders.flash.created")
      else
        render :new, status: :unprocessable_content
      end
    end

    def edit
    end

    def update
      @stakeholder = Stakeholders::UpdateDraft.call(
        case_record: @case,
        stakeholder_id: @stakeholder.id,
        attributes: stakeholder_params
      )

      if @stakeholder.errors.empty?
        redirect_to author_case_stakeholders_path(@case),
          notice: t("author.stakeholders.flash.updated")
      else
        render :edit, status: :unprocessable_content
      end
    end

    private

    def set_case
      @case = current_user.authored_cases.find(params[:case_id])
    end

    def set_stakeholder
      @stakeholder = @case.stakeholders.find(params[:id])
      authorize @stakeholder, :update?
    end

    def stakeholder_params
      params.expect(stakeholder: Stakeholder::DRAFT_EDITABLE_ATTRIBUTES)
    end
  end
end
