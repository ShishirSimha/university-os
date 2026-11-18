module Api
  module Auth
    class LogoutsController < Api::BaseController
      before_action :authenticate_for_logout

      def create
        JsonWebToken.revoke(token_payload)

        render json: {
          status: 200,
          message: "User logged out successfully",
          data: current_user.registration_json
        }
      rescue JsonWebToken::RevokedError
        render_error("Token has been revoked")
      rescue JWT::DecodeError
        render_error("Invalid token")
      end

      private

      def authenticate_for_logout
        authenticate_user!(allow_suspended: true)
      end
    end
  end
end
