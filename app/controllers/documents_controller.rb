class DocumentsController < ApplicationController
  PAGE_LIMIT = 24

  before_action :set_document, only: %i[show edit update destroy]
  before_action :set_return_to, only: %i[new create edit update destroy]
  before_action :load_reference_options, only: %i[new edit]

  def index
    @pagy, @documents = pagy(:offset, Document.order(:id), limit: PAGE_LIMIT)
  end

  def show
  end

  def new
    @document = Document.new
  end

  def create
    @document = Document.new(create_document_params)
    if @document.save
      redirect_to document_path(@document), status: :see_other
    else
      load_reference_options
      render :new, status: :unprocessable_content
    end
  end

  def edit
  end

  def update
    if @document.update(update_document_params)
      redirect_to document_path(@document), status: :see_other
    else
      load_reference_options
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @document.destroy!
    redirect_to @return_to, status: :see_other
  end

  private

  def set_document
    @document = Document.find(params[:id])
  end

  def set_return_to
    expected = case action_name
    when "new", "create"
      "foundation:mutation-record:show"
    when "edit", "update"
      document_path(@document)
    when "destroy"
      documents_path
    end
    candidate = params.fetch(:return_to, expected)
    @return_to = candidate if valid_return_to?(candidate, expected)
    raise ActionController::BadRequest, "invalid return destination" unless @return_to

    @cancel_to = case action_name
    when "new", "create"
      documents_path
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

  def create_document_params
    params.expect(document: %i[file_name description file_url byte_size given_at_start case_study_id])
  end

  def update_document_params
    params.expect(document: %i[file_name description file_url byte_size given_at_start case_study_id])
  end

  def load_reference_options
    @case_study_id_options = CaseStudy
      .order(:title, :id)
      .pluck(:title, :id)
  end
end
