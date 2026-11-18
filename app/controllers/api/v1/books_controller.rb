module Api
  module V1
    class BooksController < CatalogueController
      before_action :require_catalogue_manager!, except: %i[index show]
      before_action :set_book, only: %i[
        show update destroy publish archive submit reject withdraw audit_logs
        add_author remove_author add_subject remove_subject add_category remove_category
        add_genre remove_genre add_media
      ]

      def index
        relation = Catalogue::BookQuery.new(visible_books, params, tenant: current_tenant, admin: current_user.admin?).call
        relation = relation.preload(:original_language, :editions, book_authors: :author)
        render_page("Books retrieved successfully", :books, relation, &:summary_json)
      end

      def show
        render_data("Book retrieved successfully", detailed_book(@book))
      end

      def create
        book = Catalogue::SaveBook.new(tenant: current_tenant, actor: current_user, attrs: book_attrs).call
        render_data("Book created successfully", detailed_book(book).merge(possibleDuplicates: Catalogue::Duplicates.books(book)), status: :created)
      end

      def update
        ensure_book_editable!(@book)
        book = Catalogue::SaveBook.new(tenant: current_tenant, actor: current_user, attrs: book_attrs, book: @book).call
        render_data("Book updated successfully", detailed_book(book).merge(possibleDuplicates: Catalogue::Duplicates.books(book)))
      end

      def destroy
        @book.destroy!
        render_data("Draft deleted successfully", { id: @book.id })
      end

      def publish
        @book.transition_to!("published")
        render_data("Book published successfully", detailed_book(@book))
      end

      def archive
        @book.transition_to!("archived")
        render_data("Book archived successfully", detailed_book(@book).merge(circulationWarnings: @book.circulation_warnings))
      end

      def submit
        @book.transition_to!("under_review")
        render_data("Book submitted for review", detailed_book(@book))
      end

      def reject
        @book.transition_to!("rejected")
        render_data("Book rejected", detailed_book(@book))
      end

      def withdraw
        @book.transition_to!("withdrawn")
        render_data("Book withdrawn", detailed_book(@book))
      end

      def audit_logs
        logs = @book.audit_logs.order(created_at: :desc)
        render_page("Audit history retrieved successfully", :auditLogs, logs, &:catalogue_json)
      end

      def add_author
        ensure_book_editable!(@book)
        author = Author.find_by(id: field(:authorId, :author_id), tenant_id: current_tenant.id)
        raise Catalogue::Error, "Author was not found" unless author

        link = @book.book_authors.create!(
          author: author,
          contributor_role: field(:role, :contributorRole, :contributor_role).presence || "author",
          sequence_number: field(:sequence, :sequenceNumber, :sequence_number).presence || next_author_sequence
        )
        render_data("Contributor associated successfully", link.summary_json, status: :created)
      end

      def remove_author
        ensure_book_editable!(@book)
        link = @book.book_authors.find(params[:author_link_id])
        link.destroy!
        render_data("Contributor removed successfully", { id: link.id })
      end

      def add_subject
        ensure_book_editable!(@book)
        subject = Subject.find_by(id: field(:subjectId, :subject_id), tenant_id: current_tenant.id)
        raise Catalogue::Error, "Subject was not found" unless subject

        link = @book.book_subjects.create!(subject: subject, is_primary: boolean_field(:primary, :isPrimary, :is_primary))
        render_data("Subject associated successfully", link.summary_json, status: :created)
      end

      def remove_subject
        ensure_book_editable!(@book)
        link = @book.book_subjects.find_by!(subject_id: params[:subject_id])
        link.destroy!
        render_data("Subject removed successfully", { id: link.id })
      end

      def add_category
        ensure_book_editable!(@book)
        category = BookCategory.find_by(id: field(:categoryId, :category_id), tenant_id: current_tenant.id)
        raise Catalogue::Error, "Category was not found" unless category

        link = @book.book_category_assignments.create!(book_category: category)
        render_data("Category associated successfully", category.reference_json.merge(assignmentId: link.id), status: :created)
      end

      def remove_category
        ensure_book_editable!(@book)
        link = @book.book_category_assignments.find_by!(book_category_id: params[:category_id])
        link.destroy!
        render_data("Category removed successfully", { id: link.id })
      end

      def add_genre
        ensure_book_editable!(@book)
        genre = Genre.find_by(id: field(:genreId, :genre_id), tenant_id: current_tenant.id)
        raise Catalogue::Error, "Genre was not found" unless genre

        link = @book.book_genres.create!(genre: genre)
        render_data("Genre associated successfully", genre.reference_json.merge(assignmentId: link.id), status: :created)
      end

      def remove_genre
        ensure_book_editable!(@book)
        link = @book.book_genres.find_by!(genre_id: params[:genre_id])
        link.destroy!
        render_data("Genre removed successfully", { id: link.id })
      end

      def add_media
        ensure_book_editable!(@book)
        edition_id = field(:editionId, :edition_id)
        raise Catalogue::Error, "Edition is required" if edition_id.blank?

        edition = @book.editions.find(edition_id)
        ensure_edition_editable!(edition)
        media = edition.media.create!(
          media_type: field(:mediaType, :media_type),
          storage_key: field(:storageKey, :storage_key),
          original_filename: field(:originalFilename, :original_filename),
          mime_type: field(:mimeType, :mime_type),
          file_size: field(:fileSize, :file_size),
          width: field(:width),
          height: field(:height),
          variant: field(:variant).presence,
          alt_text: field(:altText, :alt_text),
          is_primary: boolean_field(:primary, :isPrimary, :is_primary),
          uploaded_by: current_user.id
        )
        render_data("Media recorded successfully", media.summary_json, status: :created)
      end

      private

      def set_book
        @book = visible_books.find(params[:id])
      end

      def book_attrs
        Catalogue::BookParams.new(params).to_h
      end

      def next_author_sequence
        @book.book_authors.maximum(:sequence_number).to_i + 1
      end
    end
  end
end
