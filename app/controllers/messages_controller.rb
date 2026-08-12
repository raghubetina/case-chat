class MessagesController < ApplicationController
  PAGE_LIMIT = 24

  before_action :set_message, only: %i[show edit update destroy]
  before_action :set_return_to, only: %i[new create edit update destroy]
  before_action :load_reference_options, only: %i[new edit]

  def index
    @pagy, @messages = pagy(:offset, Message.order(:id), limit: PAGE_LIMIT)
  end

  def show
  end

  def new
    @message = Message.new
  end

  def create
    @message = Message.new(create_message_params)
    if @message.save
      redirect_to message_path(@message), status: :see_other
    else
      load_reference_options
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @message.update(update_message_params)
      redirect_to message_path(@message), status: :see_other
    else
      load_reference_options
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @message.destroy!
    redirect_to @return_to, status: :see_other
  end

  private

  def set_message
    @message = Message.find(params[:id])
  end
  
  def set_return_to
    expected = case action_name
    when "new", "create"
      "foundation:mutation-record:show"
    when "edit", "update"
      message_path(@message)
    when "destroy"
      messages_path
    end
    candidate = params.fetch(:return_to, expected)
    @return_to = candidate if valid_return_to?(candidate, expected)
    raise ActionController::BadRequest, "invalid return destination" unless @return_to
  
    @cancel_to = case action_name
    when "new", "create"
      messages_path
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
  
  def create_message_params
    params.expect(message: %i[conversation_id])
  end
  
  def update_message_params
    params.expect(message: %i[conversation_id])
  end
  
  def load_reference_options
    @conversation_id_options = Conversation
      .order(:created_at, :id)
      .pluck(:created_at, :id)
  end
end
