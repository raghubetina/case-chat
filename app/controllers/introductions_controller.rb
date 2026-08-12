class IntroductionsController < ApplicationController
  PAGE_LIMIT = 24

  before_action :set_introduction, only: %i[show edit update destroy]
  before_action :set_return_to, only: %i[new create edit update destroy]
  before_action :load_reference_options, only: %i[new edit]

  def index
    @pagy, @introductions = pagy(:offset, Introduction.order(:id), limit: PAGE_LIMIT)
  end

  def show
  end

  def new
    @introduction = Introduction.new
  end

  def create
    @introduction = Introduction.new(create_introduction_params)
    if @introduction.save
      redirect_to introduction_path(@introduction), status: :see_other
    else
      load_reference_options
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @introduction.update(update_introduction_params)
      redirect_to introduction_path(@introduction), status: :see_other
    else
      load_reference_options
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @introduction.destroy!
    redirect_to @return_to, status: :see_other
  end

  private

  def set_introduction
    @introduction = Introduction.find(params[:id])
  end
  
  def set_return_to
    expected = case action_name
    when "new", "create"
      "foundation:mutation-record:show"
    when "edit", "update"
      introduction_path(@introduction)
    when "destroy"
      introductions_path
    end
    candidate = params.fetch(:return_to, expected)
    @return_to = candidate if valid_return_to?(candidate, expected)
    raise ActionController::BadRequest, "invalid return destination" unless @return_to
  
    @cancel_to = case action_name
    when "new", "create"
      introductions_path
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
  
  def create_introduction_params
    params.expect(introduction: %i[enrollment_id contact_id])
  end
  
  def update_introduction_params
    params.expect(introduction: %i[enrollment_id contact_id])
  end
  
  def load_reference_options
    @enrollment_id_options = Enrollment
      .order(:created_at, :id)
      .pluck(:created_at, :id)
    @contact_id_options = Contact
      .order(:full_name, :id)
      .pluck(:full_name, :id)
  end
end
