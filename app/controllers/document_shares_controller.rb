class DocumentSharesController < ApplicationController
  PAGE_LIMIT = 24

  before_action :set_document_share, only: %i[show edit update destroy]
  before_action :set_return_to, only: %i[new create edit update destroy]
  before_action :load_reference_options, only: %i[new edit]

  def index
    @pagy, @document_shares = pagy(:offset, DocumentShare.order(:id), limit: PAGE_LIMIT)
  end

  def show
  end

  def new
    @document_share = DocumentShare.new
  end

  def create
    @document_share = DocumentShare.new(create_document_share_params)
    if @document_share.save
      redirect_to document_share_path(@document_share), status: :see_other
    else
      load_reference_options
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @document_share.update(update_document_share_params)
      redirect_to document_share_path(@document_share), status: :see_other
    else
      load_reference_options
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @document_share.destroy!
    redirect_to @return_to, status: :see_other
  end

  private

  def set_document_share
    @document_share = DocumentShare.find(params[:id])
  end
  
  def set_return_to
    expected = case action_name
    when "new", "create"
      "foundation:mutation-record:show"
    when "edit", "update"
      document_share_path(@document_share)
    when "destroy"
      document_shares_path
    end
    candidate = params.fetch(:return_to, expected)
    @return_to = candidate if valid_return_to?(candidate, expected)
    raise ActionController::BadRequest, "invalid return destination" unless @return_to
  
    @cancel_to = case action_name
    when "new", "create"
      document_shares_path
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
  
  def create_document_share_params
    params.expect(document_share: %i[message_id document_id])
  end
  
  def update_document_share_params
    params.expect(document_share: %i[message_id document_id])
  end
  
  def load_reference_options
    @message_id_options = Message
      .order(:created_at, :id)
      .pluck(:created_at, :id)
    @document_id_options = Document
      .order(:file_name, :id)
      .pluck(:file_name, :id)
  end
end
