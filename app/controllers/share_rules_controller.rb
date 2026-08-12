class ShareRulesController < ApplicationController
  PAGE_LIMIT = 24

  before_action :authenticate
  before_action :set_share_rule, only: %i[show edit update destroy]
  before_action :set_return_to, only: %i[new create edit update destroy]
  before_action :load_reference_options, only: %i[new edit]

  def index
    authorize! ShareRule, to: :index?
    @pagy, @share_rules = pagy(:offset, authorized_scope(ShareRule.order(:id)), limit: PAGE_LIMIT)
  end

  def show
  end

  def new
    authorize! ShareRule, to: :new?
    @share_rule = ShareRule.new
  end

  def create
    @share_rule = ShareRule.new(create_share_rule_params)
    authorize! @share_rule
    if @share_rule.save
      redirect_to share_rule_path(@share_rule), status: :see_other
    else
      load_reference_options
      render :new, status: :unprocessable_content
    end
  end

  def edit
  end

  def update
    if @share_rule.update(update_share_rule_params)
      redirect_to share_rule_path(@share_rule), status: :see_other
    else
      load_reference_options
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @share_rule.destroy!
    redirect_to @return_to, status: :see_other
  end

  private

  def set_share_rule
    @share_rule = ShareRule.includes(contact: :case_study).find(params[:id])
    authorize! @share_rule
  end

  def set_return_to
    expected = case action_name
    when "new", "create"
      "foundation:mutation-record:show"
    when "edit", "update"
      share_rule_path(@share_rule)
    when "destroy"
      share_rules_path
    end
    candidate = params.fetch(:return_to, expected)
    @return_to = candidate if valid_return_to?(candidate, expected)
    raise ActionController::BadRequest, "invalid return destination" unless @return_to

    @cancel_to = case action_name
    when "new", "create"
      share_rules_path
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

  def create_share_rule_params
    params.expect(share_rule: %i[condition contact_id document_id])
  end

  def update_share_rule_params
    params.expect(share_rule: %i[condition contact_id document_id])
  end

  def load_reference_options
    @contact_id_options = authorized_scope(Contact.order(:full_name, :id), as: :authored)
      .pluck(:full_name, :id)
    @document_id_options = authorized_scope(Document.order(:file_name, :id), as: :authored)
      .pluck(:file_name, :id)
  end
end
