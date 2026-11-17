module Api
  module Auth
    class RegistrationsController < Api::BaseController
      def create
        user = User.new(registration_attributes)
        user.save!
        render json: {
          status: 201,
          message: "User registered successfully",
          data: {
            token: JsonWebToken.encode(user.id),
            user: user.registration_json
          }
        }, status: :created
      rescue ActiveRecord::RecordInvalid => error
        render_error(error.record.errors.full_messages.to_sentence)
      rescue ActiveRecord::RecordNotUnique
        render_error("Email has already been taken")
      end

      private

      def registration_attributes
        source = params.permit(
          :email, :password, :name, :country, :state, :address,
          :accountType, :account_type, :countryCode, :country_code,
          :phoneNumber, :phone_number
        )

        {
          email: source[:email],
          password: source[:password],
          name: source[:name],
          account_type: first_present(source, :accountType, :account_type),
          country: source[:country],
          country_code: first_present(source, :countryCode, :country_code),
          state: source[:state],
          address: source[:address],
          phone_number: first_present(source, :phoneNumber, :phone_number)
        }
      end

      def first_present(source, *keys)
        keys.lazy.filter_map { |key| source[key].presence }.first
      end
    end
  end
end
