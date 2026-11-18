module Api
  module V1
    class AuthorsController < CatalogueController
      before_action :require_catalogue_manager!
      before_action :set_author, only: %i[show update archive]

      def index
        scope = Author.where(tenant_id: current_tenant.id).order(:display_name)
        if params[:q].present?
          scope = scope.where(
            "display_name ILIKE :q OR first_name ILIKE :q OR last_name ILIKE :q",
            q: like_term(params[:q])
          )
        end
        render_page("Authors retrieved successfully", :authors, scope, &:reference_json)
      end

      def show
        render_data("Author retrieved successfully", @author.reference_json)
      end

      def create
        author = save_author(Author.new(tenant: current_tenant))
        render_data(
          "Author created successfully",
          author.reference_json.merge(possibleDuplicates: Catalogue::Duplicates.authors(author)),
          status: :created
        )
      end

      def update
        author = save_author(@author)
        render_data("Author updated successfully", author.reference_json.merge(possibleDuplicates: Catalogue::Duplicates.authors(author)))
      end

      def archive
        @author.update!(status: "archived")
        render_data("Author archived successfully", @author.reference_json)
      end

      private

      def set_author
        @author = Author.where(tenant_id: current_tenant.id).find(params[:id])
      end

      def save_author(author)
        Author.transaction do
          author.assign_attributes(author_attributes)
          author.save!
          replace_aliases(author) if field?(:aliases)
          author.reload
        end
      end

      def author_attributes
        attrs = {}
        attrs[:first_name] = field(:firstName, :first_name) if field?(:firstName, :first_name)
        attrs[:middle_name] = field(:middleName, :middle_name) if field?(:middleName, :middle_name)
        attrs[:last_name] = field(:lastName, :last_name) if field?(:lastName, :last_name)
        attrs[:display_name] = field(:displayName, :display_name) if field?(:displayName, :display_name)
        attrs[:biography] = field(:biography) if field?(:biography)
        attrs[:orcid] = field(:orcid) if field?(:orcid)
        attrs[:nationality_code] = field(:nationalityCode, :nationality_code) if field?(:nationalityCode, :nationality_code)
        attrs
      end

      def replace_aliases(author)
        author.aliases.destroy_all
        alias_names.each { |name| author.aliases.create!(name: name) }
      end

      def alias_names
        raw = field(:aliases)
        raise Catalogue::Error, "Aliases must be a list" unless raw.is_a?(Array)

        raw.map do |entry|
          next entry if entry.is_a?(String)

          raise Catalogue::Error, "Each alias must be a name" unless entry.respond_to?(:[])

          entry[:name] || entry["name"]
        end
      end
    end
  end
end
