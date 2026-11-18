module Api
  module Auth
    class LogoutsController < Api::BaseController
      def create
        token = bearer_token
        return render_error("Authorization token is required") if token.blank?

        payload = JsonWebToken.decode(token)
        user = User.find(payload.fetch("sub"))
        JsonWebToken.revoke(payload)

        render json: {
          status: 200,
          message: "User logged out successfully",
          data: user.registration_json
        }
      rescue JsonWebToken::RevokedError
        render_error("Token has been revoked")
      rescue JWT::ExpiredSignature
        render_error("Token has expired")
      rescue JWT::DecodeError, ActiveRecord::RecordNotFound
        render_error("Invalid token")
      end

      private

      def bearer_token
        scheme, token = request.authorization.to_s.split(" ", 2)
        token if scheme&.casecmp("bearer")&.zero? && token.present?
      end
    end
  end
end
