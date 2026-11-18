module Api
  module Auth
    class LoginController < Api::BaseController
      include InstitutionResolution

      def create
        tenant = require_active_institution
        return unless tenant

        user = User.find_by(tenant_id: tenant.id, email: normalized_email)
        unless user&.authenticate(password_param)
          return render_error("Invalid email or password")
        end

        render json: {
          status: 200,
          message: "Login successfully",
          data: {
            token: JsonWebToken.encode(user.id, user.tenant_id),
            user: user.registration_json
          }
        }
      end

      private

      def normalized_email
        email_param.to_s.strip.downcase
      end

      def email_param
        source[:email].presence || source[:emai].presence
      end

      def password_param
        source[:password].to_s
      end

      def source
        @source ||= params.permit(:email, :emai, :password)
      end
    end
  end
end
