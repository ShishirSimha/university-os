module Api
  module V1
    class SubjectsController < CatalogueController
      before_action :require_catalogue_manager!
      before_action :set_subject, only: %i[show update archive]

      def index
        scope = Subject.where(tenant_id: current_tenant.id).order(:name)
        scheme = field(:classificationScheme, :classification_scheme)
        scope = scope.where(classification_scheme: scheme.to_s.strip.upcase) if scheme.present?
        scope = scope.where("name ILIKE :q OR code = :code", q: like_term(params[:q]), code: params[:q].to_s.strip.upcase) if params[:q].present?
        render_page("Subjects retrieved successfully", :subjects, scope, &:reference_json)
      end

      def show
        render_data("Subject retrieved successfully", @subject.reference_json)
      end

      def create
        subject = Subject.create!(subject_attributes.merge(tenant: current_tenant))
        render_data("Subject created successfully", subject.reference_json, status: :created)
      end

      def update
        @subject.update!(subject_attributes)
        render_data("Subject updated successfully", @subject.reference_json)
      end

      def archive
        @subject.update!(status: "archived")
        render_data("Subject archived successfully", @subject.reference_json)
      end

      private

      def set_subject
        @subject = Subject.where(tenant_id: current_tenant.id).find(params[:id])
      end

      def subject_attributes
        attrs = {}
        attrs[:name] = field(:name) if field?(:name)
        attrs[:code] = field(:code) if field?(:code)
        attrs[:description] = field(:description) if field?(:description)
        attrs[:classification_scheme] = field(:classificationScheme, :classification_scheme) if field?(:classificationScheme, :classification_scheme)
        attrs[:external_identifier] = field(:externalIdentifier, :external_identifier) if field?(:externalIdentifier, :external_identifier)
        if field?(:parentId, :parent_id)
          parent_id = field(:parentId, :parent_id)
          if parent_id.present? && !Subject.exists?(id: parent_id, tenant_id: current_tenant.id)
            raise Catalogue::Error, "Parent subject was not found"
          end
          attrs[:parent_id] = parent_id.presence
        end
        attrs
      end
    end
  end
end
