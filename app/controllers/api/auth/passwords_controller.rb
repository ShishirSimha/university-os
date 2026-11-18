module Api
  module Auth
    class PasswordsController < Api::BaseController
      include InstitutionResolution

      def create
        return render_error("Email can't be blank") if normalized_email.blank?
        return render_error("Password can't be blank") if source[:password].blank?

        tenant = require_active_institution
        return unless tenant

        user = User.find_by(tenant_id: tenant.id, email: normalized_email)
        return render_error("Email not found") unless user

        user.password = source[:password]
        user.save!

        render json: {
          status: 200,
          message: "User password reset successfully",
          data: user.registration_json
        }
      rescue ActiveRecord::RecordInvalid => error
        render_error(error.record.errors.full_messages.to_sentence)
      end

      private

      def normalized_email
        email_param.to_s.strip.downcase
      end

      def email_param
        source[:email].presence || source[:emai].presence
      end

      def source
        @source ||= params.permit(:email, :emai, :password)
      end
    end
  end
end
