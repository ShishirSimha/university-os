module Api
  module V1
    class BookFormatsController < CatalogueController
      def index
        formats = BookFormat.active.order(:name)
        render_data("Formats retrieved successfully", { formats: formats.map(&:reference_json) })
      end

      def show
        render_data("Format retrieved successfully", BookFormat.active.find(params[:id]).reference_json)
      end
    end
  end
end
