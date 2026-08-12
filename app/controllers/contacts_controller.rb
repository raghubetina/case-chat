class ContactsController < ApplicationController
  PAGE_LIMIT = 24

  before_action :set_contact, only: %i[show edit update destroy]
  before_action :set_return_to, only: %i[new create edit update destroy]
  before_action :load_reference_options, only: %i[new edit]

  def index
    @pagy, @contacts = pagy(:offset, Contact.order(:id), limit: PAGE_LIMIT)
  end

  def show
  end

  def new
    @contact = Contact.new
  end

  def create
    @contact = Contact.new(create_contact_params)
    if @contact.save
      redirect_to contact_path(@contact), status: :see_other
    else
      load_reference_options
      render :new, status: :unprocessable_content
    end
  end

  def edit
  end

  def update
    if @contact.update(update_contact_params)
      redirect_to contact_path(@contact), status: :see_other
    else
      load_reference_options
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @contact.destroy!
    redirect_to @return_to, status: :see_other
  end

  private

  def set_contact
    @contact = Contact.find(params[:id])
  end

  def set_return_to
    expected = case action_name
    when "new", "create"
      "foundation:mutation-record:show"
    when "edit", "update"
      contact_path(@contact)
    when "destroy"
      contacts_path
    end
    candidate = params.fetch(:return_to, expected)
    @return_to = candidate if valid_return_to?(candidate, expected)
    raise ActionController::BadRequest, "invalid return destination" unless @return_to

    @cancel_to = case action_name
    when "new", "create"
      contacts_path
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

  def create_contact_params
    params.expect(contact: %i[full_name role_title case_study_id])
  end

  def update_contact_params
    params.expect(contact: %i[full_name role_title case_study_id])
  end

  def load_reference_options
    @case_study_id_options = CaseStudy
      .order(:title, :id)
      .pluck(:title, :id)
  end
end
