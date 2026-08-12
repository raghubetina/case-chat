class UsersController < ApplicationController
  PAGE_LIMIT = 24

  before_action :set_user, only: %i[show edit update destroy]
  before_action :set_return_to, only: %i[new create edit update destroy]

  def index
    @pagy, @users = pagy(:offset, User.order(:id), limit: PAGE_LIMIT)
  end

  def show
  end

  def new
    @user = User.new
  end

  def create
    @user = User.new(create_user_params)
    if @user.save
      redirect_to user_path(@user), status: :see_other
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
  end

  def update
    if @user.update(update_user_params)
      redirect_to user_path(@user), status: :see_other
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @user.destroy!
    redirect_to @return_to, status: :see_other
  end

  private

  def set_user
    @user = User.find(params[:id])
  end

  def set_return_to
    expected = case action_name
    when "new", "create"
      "foundation:mutation-record:show"
    when "edit", "update"
      user_path(@user)
    when "destroy"
      users_path
    end
    candidate = params.fetch(:return_to, expected)
    @return_to = candidate if valid_return_to?(candidate, expected)
    raise ActionController::BadRequest, "invalid return destination" unless @return_to

    @cancel_to = case action_name
    when "new", "create"
      users_path
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

  def create_user_params
    params.expect(user: %i[full_name email program])
  end

  def update_user_params
    params.expect(user: %i[full_name email program])
  end
end
