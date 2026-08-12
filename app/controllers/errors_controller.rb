# Branded error pages, routed via config.exceptions_app. Inheriting directly
# from ActionController::Base keeps future authentication or other application
# callbacks from breaking the error renderer. If this renderer itself raises,
# ActionDispatch::ShowExceptions returns its minimal plain-text failsafe.
# standard:disable Rails/ApplicationController
class ErrorsController < ActionController::Base
  layout "application"

  def not_found
    render_error status: :not_found, message: t("errors.not_found.heading")
  end

  def unprocessable
    render_error status: :unprocessable_content, message: t("errors.unprocessable.heading")
  end

  def internal_error
    render_error status: :internal_server_error, message: t("errors.internal_error.heading")
  end

  private

  # Exceptions can originate from an API-shaped request. The public error
  # endpoints only have HTML templates, so rendering them as JSON would turn
  # the original error into a misleading template-missing 500.
  def render_error(status:, message:)
    if request.format.json? || request.content_mime_type == Mime[:json]
      render json: {error: message}, status:
    else
      render status:, formats: :html
    end
  end
end
# standard:enable Rails/ApplicationController
