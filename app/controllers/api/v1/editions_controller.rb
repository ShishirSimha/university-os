module Api
  module V1
    class EditionsController < CatalogueController
      before_action :require_catalogue_manager!, except: %i[index show]
      before_action :set_book, only: %i[index create]
      before_action :set_edition, only: %i[update destroy add_identifier add_contributor]

      def index
        editions = @book.editions.order(:created_at).preload(:publisher, :language, :format, :identifiers, :media, contributors: :author)
        render_page("Editions retrieved successfully", :editions, editions, &:detail_json)
      end

      def show
        render_data("Edition retrieved successfully", visible_edition.detail_json)
      end

      def create
        ensure_book_editable!(@book)
        edition = Catalogue::SaveEdition.new(tenant: current_tenant, book: @book, attrs: edition_attrs).call
        render_data("Edition created successfully", edition.detail_json, status: :created)
      end

      def update
        ensure_edition_editable!(@edition)
        edition = Catalogue::SaveEdition.new(
          tenant: current_tenant,
          book: @edition.book,
          edition: @edition,
          attrs: edition_attrs
        ).call
        render_data("Edition updated successfully", edition.detail_json)
      end

      def destroy
        unless @edition.book.draft?
          return render_error("Only editions of a draft can be deleted", status: :conflict)
        end

        @edition.destroy!
        render_data("Edition deleted successfully", { id: @edition.id })
      end

      def add_identifier
        ensure_edition_editable!(@edition)
        identifier = @edition.identifiers.create!(
          identifier_type: field(:type, :identifierType, :identifier_type),
          identifier_value: field(:value, :identifierValue, :identifier_value),
          is_primary: boolean_field(:primary, :isPrimary, :is_primary)
        )
        render_data("Identifier added successfully", identifier.summary_json, status: :created)
      end

      def add_contributor
        ensure_edition_editable!(@edition)
        author = Author.find_by(id: field(:authorId, :author_id), tenant_id: current_tenant.id)
        raise Catalogue::Error, "Author was not found" unless author

        link = @edition.contributors.create!(
          author: author,
          contributor_role: field(:role, :contributorRole, :contributor_role).presence || "translator",
          sequence_number: field(:sequence, :sequenceNumber, :sequence_number).presence || 1
        )
        render_data("Contributor associated successfully", link.summary_json, status: :created)
      end

      private

      def set_book
        @book = visible_books.find(params[:book_id])
      end

      def set_edition
        @edition = BookEdition.where(tenant_id: current_tenant.id).find(params[:id])
      end

      def visible_edition
        scope = BookEdition.where(tenant_id: current_tenant.id)
        scope = scope.joins(:book).where(books: { status: "published" }) unless current_user.admin?
        scope.find(params[:id])
      end

      def edition_attrs
        Catalogue::EditionParams.new(params).to_h
      end
    end
  end
end
