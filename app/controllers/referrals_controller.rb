class ReferralsController < ApplicationController
  PAGE_LIMIT = 24

  before_action :authenticate
  before_action :set_referral, only: %i[show edit update destroy]
  before_action :set_return_to, only: %i[new create edit update destroy]
  before_action :load_reference_options, only: %i[new edit]

  def index
    authorize! Referral, to: :index?
    @pagy, @referrals = pagy(:offset, authorized_scope(Referral.order(:id)), limit: PAGE_LIMIT)
  end

  def show
  end

  def new
    authorize! Referral, to: :new?
    @referral = Referral.new
  end

  def create
    @referral = Referral.new(create_referral_params)
    authorize! @referral
    if @referral.save
      redirect_to referral_path(@referral), status: :see_other
    else
      load_reference_options
      render :new, status: :unprocessable_content
    end
  end

  def edit
  end

  def update
    if @referral.update(update_referral_params)
      redirect_to referral_path(@referral), status: :see_other
    else
      load_reference_options
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @referral.destroy!
    redirect_to @return_to, status: :see_other
  end

  private

  def set_referral
    @referral = Referral.includes(referring_contact: :case_study).find(params[:id])
    authorize! @referral
  end

  def set_return_to
    expected = case action_name
    when "new", "create"
      "foundation:mutation-record:show"
    when "edit", "update"
      referral_path(@referral)
    when "destroy"
      referrals_path
    end
    candidate = params.fetch(:return_to, expected)
    @return_to = candidate if valid_return_to?(candidate, expected)
    raise ActionController::BadRequest, "invalid return destination" unless @return_to

    @cancel_to = case action_name
    when "new", "create"
      referrals_path
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

  def create_referral_params
    params.expect(referral: %i[condition enabled referring_contact_id referred_contact_id])
  end

  def update_referral_params
    params.expect(referral: %i[condition enabled referring_contact_id referred_contact_id])
  end

  def load_reference_options
    @referring_contact_id_options = authorized_scope(Contact.order(:full_name, :id), as: :authored)
      .pluck(:full_name, :id)
    @referred_contact_id_options = authorized_scope(Contact.order(:full_name, :id), as: :authored)
      .pluck(:full_name, :id)
  end
end
