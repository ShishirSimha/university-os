module Api
  module V1
    class LanguagesController < CatalogueController
      def index
        languages = Language.active.order(:name)
        render_data("Languages retrieved successfully", { languages: languages.map(&:reference_json) })
      end

      def show
        render_data("Language retrieved successfully", Language.active.find(params[:id]).reference_json)
      end
    end
  end
end
