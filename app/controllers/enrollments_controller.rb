class EnrollmentsController < ApplicationController
  PAGE_LIMIT = 24

  before_action :authenticate
  before_action :set_enrollment, only: %i[show edit update destroy]
  before_action :set_return_to, only: %i[new create edit update destroy]
  before_action :load_reference_options, only: %i[new edit]

  def index
    authorize! Enrollment, to: :index?
    @pagy, @enrollments = pagy(:offset, authorized_scope(Enrollment.order(:id)), limit: PAGE_LIMIT)
  end

  def show
  end

  def new
    authorize! Enrollment, to: :new?
    @enrollment = Enrollment.new
  end

  def create
    @enrollment = Enrollment.new(create_enrollment_params)
    authorize! @enrollment
    if @enrollment.save
      redirect_to enrollment_path(@enrollment), status: :see_other
    else
      load_reference_options
      render :new, status: :unprocessable_content
    end
  end

  def edit
  end

  def update
    if @enrollment.update(update_enrollment_params)
      redirect_to enrollment_path(@enrollment), status: :see_other
    else
      load_reference_options
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @enrollment.destroy!
    redirect_to @return_to, status: :see_other
  end

  private

  def set_enrollment
    @enrollment = Enrollment.includes(:case_study).find(params[:id])
    authorize! @enrollment
  end

  def set_return_to
    expected = case action_name
    when "new", "create"
      "foundation:mutation-record:show"
    when "edit", "update"
      enrollment_path(@enrollment)
    when "destroy"
      enrollments_path
    end
    candidate = params.fetch(:return_to, expected)
    @return_to = candidate if valid_return_to?(candidate, expected)
    raise ActionController::BadRequest, "invalid return destination" unless @return_to

    @cancel_to = case action_name
    when "new", "create"
      enrollments_path
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

  def create_enrollment_params
    params.expect(enrollment: %i[user_id case_study_id])
  end

  def update_enrollment_params
    params.expect(enrollment: %i[user_id case_study_id])
  end

  def load_reference_options
    @user_id_options = authorized_scope(User.order(:full_name, :id))
      .pluck(:full_name, :id)
    @case_study_id_options = authorized_scope(CaseStudy.order(:title, :id))
      .pluck(:title, :id)
  end
end
