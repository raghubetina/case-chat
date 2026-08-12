class CaseStudiesController < ApplicationController
  PAGE_LIMIT = 24

  before_action :set_case_study, only: %i[show edit update destroy]
  before_action :set_return_to, only: %i[new create edit update destroy]
  before_action :load_reference_options, only: %i[new edit]

  def index
    @pagy, @case_studies = pagy(:offset, CaseStudy.order(:id), limit: PAGE_LIMIT)
  end

  def show
  end

  def new
    @case_study = CaseStudy.new
  end

  def create
    @case_study = CaseStudy.new(create_case_study_params)
    if @case_study.save
      redirect_to case_study_path(@case_study), status: :see_other
    else
      load_reference_options
      render :new, status: :unprocessable_content
    end
  end

  def edit
  end

  def update
    if @case_study.update(update_case_study_params)
      redirect_to case_study_path(@case_study), status: :see_other
    else
      load_reference_options
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @case_study.destroy!
    redirect_to @return_to, status: :see_other
  end

  private

  def set_case_study
    @case_study = CaseStudy.find(params[:id])
  end

  def set_return_to
    expected = case action_name
    when "new", "create"
      "foundation:mutation-record:show"
    when "edit", "update"
      case_study_path(@case_study)
    when "destroy"
      case_studies_path
    end
    candidate = params.fetch(:return_to, expected)
    @return_to = candidate if valid_return_to?(candidate, expected)
    raise ActionController::BadRequest, "invalid return destination" unless @return_to

    @cancel_to = case action_name
    when "new", "create"
      case_studies_path
    when "edit", "update"
      @return_to
    end
  end

  def valid_return_to?(candidate, expected)
    if expected == "foundation:mutation-record:show"
      candidate == expected
    else
      url_from(candidate) == expected
    end
  end

  def create_case_study_params
    params.expect(case_study: %i[title course background assignment join_code due_at published author_id])
  end

  def update_case_study_params
    params.expect(case_study: %i[title course background assignment join_code due_at published author_id])
  end

  def load_reference_options
    @author_id_options = User
      .order(:full_name, :id)
      .pluck(:full_name, :id)
  end
end
