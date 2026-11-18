module Api
  module V1
    class GenresController < CatalogueController
      before_action :require_catalogue_manager!
      before_action :set_genre, only: %i[show update archive]

      def index
        scope = Genre.where(tenant_id: current_tenant.id).order(:name)
        scope = scope.where("name ILIKE :q OR code = :code", q: like_term(params[:q]), code: params[:q].to_s.strip.upcase) if params[:q].present?
        render_page("Genres retrieved successfully", :genres, scope, &:reference_json)
      end

      def show
        render_data("Genre retrieved successfully", @genre.reference_json)
      end

      def create
        genre = Genre.create!(genre_attributes.merge(tenant: current_tenant))
        render_data("Genre created successfully", genre.reference_json, status: :created)
      end

      def update
        @genre.update!(genre_attributes)
        render_data("Genre updated successfully", @genre.reference_json)
      end

      def archive
        @genre.update!(status: "archived")
        render_data("Genre archived successfully", @genre.reference_json)
      end

      private

      def set_genre
        @genre = Genre.where(tenant_id: current_tenant.id).find(params[:id])
      end

      def genre_attributes
        attrs = {}
        attrs[:name] = field(:name) if field?(:name)
        attrs[:code] = field(:code) if field?(:code)
        attrs
      end
    end
  end
end
