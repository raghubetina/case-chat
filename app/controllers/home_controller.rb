class HomeController < ApplicationController
  # Signed-in visitors have somewhere to be; the landing page is for everyone
  # else.
  def index
    redirect_to cases_path if current_user
  end
end
