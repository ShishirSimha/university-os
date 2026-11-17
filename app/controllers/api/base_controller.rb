module Api
  class BaseController < ActionController::API
    private

    def render_error(message, status: :bad_request)
      render json: { status: Rack::Utils.status_code(status), message: message }, status: status
    end
  end
end
