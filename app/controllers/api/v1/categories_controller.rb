module Api
  module V1
    class CategoriesController < CatalogueController
      before_action :require_catalogue_manager!
      before_action :set_category, only: %i[show update archive]

      def index
        scope = BookCategory.where(tenant_id: current_tenant.id).order(:name)
        scope = scope.where("name ILIKE :q OR code = :code", q: like_term(params[:q]), code: params[:q].to_s.strip.upcase) if params[:q].present?
        render_page("Categories retrieved successfully", :categories, scope, &:reference_json)
      end

      def show
        render_data("Category retrieved successfully", @category.reference_json)
      end

      def create
        category = BookCategory.create!(category_attributes.merge(tenant: current_tenant))
        render_data("Category created successfully", category.reference_json, status: :created)
      end

      def update
        @category.update!(category_attributes)
        render_data("Category updated successfully", @category.reference_json)
      end

      def archive
        @category.update!(status: "archived")
        render_data("Category archived successfully", @category.reference_json)
      end

      private

      def set_category
        @category = BookCategory.where(tenant_id: current_tenant.id).find(params[:id])
      end

      def category_attributes
        attrs = {}
        attrs[:name] = field(:name) if field?(:name)
        attrs[:code] = field(:code) if field?(:code)
        attrs[:description] = field(:description) if field?(:description)
        if field?(:parentId, :parent_id)
          parent_id = field(:parentId, :parent_id)
          if parent_id.present? && !BookCategory.exists?(id: parent_id, tenant_id: current_tenant.id)
            raise Catalogue::Error, "Parent category was not found"
          end
          attrs[:parent_id] = parent_id.presence
        end
        attrs
      end
    end
  end
end
