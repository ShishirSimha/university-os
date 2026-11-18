module Api
  module V1
    class PublishersController < CatalogueController
      before_action :require_catalogue_manager!
      before_action :set_publisher, only: %i[show update archive]

      def index
        scope = Publisher.where(tenant_id: current_tenant.id).order(:name)
        scope = scope.where("name ILIKE ?", like_term(params[:q])) if params[:q].present?
        render_page("Publishers retrieved successfully", :publishers, scope, &:reference_json)
      end

      def show
        render_data("Publisher retrieved successfully", @publisher.reference_json)
      end

      def create
        publisher = Publisher.create!(publisher_attributes.merge(tenant: current_tenant))
        render_data("Publisher created successfully", publisher.reference_json, status: :created)
      end

      def update
        @publisher.update!(publisher_attributes)
        render_data("Publisher updated successfully", @publisher.reference_json)
      end

      def archive
        @publisher.update!(status: "archived")
        render_data("Publisher archived successfully", @publisher.reference_json)
      end

      private

      def set_publisher
        @publisher = Publisher.where(tenant_id: current_tenant.id).find(params[:id])
      end

      def publisher_attributes
        attrs = {}
        attrs[:name] = field(:name) if field?(:name)
        attrs[:description] = field(:description) if field?(:description)
        attrs[:website] = field(:website) if field?(:website)
        attrs[:country_code] = field(:countryCode, :country_code) if field?(:countryCode, :country_code)
        attrs[:email] = field(:email) if field?(:email)
        attrs
      end
    end
  end
end
