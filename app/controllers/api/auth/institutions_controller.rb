module Api
  module Auth
    class InstitutionsController < Api::BaseController
      def create
        institution = Tenant.new(name: source[:name], code: source[:code])
        institution.save!

        render json: {
          status: 201,
          message: "Institution created successfully",
          data: institution.institution_json
        }, status: :created
      rescue ActiveRecord::RecordInvalid => error
        render_error(error.record.errors.full_messages.to_sentence)
      rescue ActiveRecord::RecordNotUnique
        render_error("Institution code has already been taken")
      end

      private

      def source
        params.permit(:name, :code)
      end
    end
  end
end
