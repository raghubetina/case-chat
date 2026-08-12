class DocumentsController < ApplicationController
  PAGE_LIMIT = 24

  before_action :authenticate
  before_action :set_document, only: %i[show edit update destroy download]
  before_action :set_return_to, only: %i[new create edit update destroy]
  before_action :load_reference_options, only: %i[new edit]

  def index
    authorize! Document, to: :index?
    @pagy, @documents = pagy(:offset, authorized_scope(Document.order(:id)), limit: PAGE_LIMIT)
  end

  def show
  end

  def new
    authorize! Document, to: :new?
    @document = Document.new
  end

  def create
    @document = Document.new(create_document_params)
    authorize! @document
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

  # Downloads go through the app rather than a signed Active Storage URL: a
  # signed URL keeps working after the student loses access, and "you only see
  # what you earned" is the product, not a detail.
  # Only attached files are served here. A file_url is author-supplied, so
  # redirecting to it would make this app an open redirect — the views render
  # it as an ordinary outbound link instead, where a student can see where
  # they are going before they click.
  def download
    if @document.file.attached?
      redirect_to rails_blob_path(@document.file, disposition: "attachment")
    else
      redirect_back_or_to(cases_path, alert: t("documents.missing"))
    end
  end

  def destroy
    @document.destroy!
    redirect_to @return_to, status: :see_other
  end

  private

  def set_document
    @document = Document.includes(:case_study).find(params[:id])
    authorize! @document
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
    @case_study_id_options = authorized_scope(CaseStudy.order(:title, :id), as: :authored)
      .pluck(:title, :id)
  end
end
