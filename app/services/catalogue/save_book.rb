module Catalogue
  class SaveBook
    def initialize(tenant:, actor:, attrs:, book: nil)
      @tenant = tenant
      @actor = actor
      @attrs = attrs
      @book = book
      @creating = book.nil?
    end

    def call
      Book.transaction do
        @book ||= Book.new(tenant: @tenant, created_by: @actor.id, status: "draft")
        raise Error.new("Archived books cannot be edited", status: :conflict) unless @creating || @book.editable?

        assign_scalars
        @book.updated_by = @actor.id
        @book.audit_reason = @attrs[:reason]
        @book.save!
        sync_authors if @attrs.key?(:authors)
        sync_subjects if @attrs.key?(:subject_ids)
        sync_categories if @attrs.key?(:category_ids)
        sync_genres if @attrs.key?(:genre_ids)
        sync_metadata if @attrs.key?(:metadata)
        sync_editions if @attrs.key?(:editions)
        @book
      end
    end

    private

    def assign_scalars
      @book.title = @attrs[:title] if @attrs.key?(:title)
      @book.subtitle = @attrs[:subtitle] if @attrs.key?(:subtitle)
      @book.description = @attrs[:description] if @attrs.key?(:description)
      @book.work_type = @attrs[:work_type] if @attrs.key?(:work_type) && @attrs[:work_type].present?
      @book.catalogue_number = @attrs[:catalogue_number] if @attrs.key?(:catalogue_number)
      assign_language if @attrs.key?(:original_language_id) || @attrs.key?(:original_language_code)
      @book.primary_category_id = @attrs[:primary_category_id] if @attrs.key?(:primary_category_id)
    end

    def assign_language
      @book.original_language = References.language(@attrs[:original_language_id], @attrs[:original_language_code])
    end

    def sync_authors
      previous = @book.book_authors.map(&:summary_json)
      @book.book_authors.destroy_all
      Array(@attrs[:authors]).each_with_index do |entry, index|
        author = Author.find_by(id: entry[:author_id], tenant_id: @tenant.id)
        raise Error, "Author was not found" unless author

        @book.book_authors.create!(
          author: author,
          contributor_role: entry[:role].presence || "author",
          sequence_number: entry[:sequence].presence || index + 1
        )
      end
      return if @creating

      AuditRecorder.record!(
        book: @book,
        action: "UPDATE",
        old_values: { authors: previous },
        new_values: { authors: @book.book_authors.reload.map(&:summary_json) },
        reason: @attrs[:reason]
      )
    end

    def sync_subjects
      ids = Array(@attrs[:subject_ids]).map(&:to_s).uniq
      primary_id = @attrs[:primary_subject_id].presence&.to_s || ids.first
      @book.book_subjects.destroy_all
      ids.each do |id|
        subject = Subject.find_by(id: id, tenant_id: @tenant.id)
        raise Error, "Subject was not found" unless subject

        @book.book_subjects.create!(subject: subject, is_primary: id == primary_id)
      end
    end

    def sync_categories
      ids = Array(@attrs[:category_ids]).map(&:to_s)
      if @attrs[:primary_category_id].present?
        @book.primary_category_id = @attrs[:primary_category_id]
      elsif ids.any? && @book.primary_category_id.blank?
        @book.primary_category_id = ids.first
      end
      ids << @book.primary_category_id.to_s if @book.primary_category_id.present?
      @book.book_category_assignments.destroy_all
      ids.compact_blank.uniq.each do |id|
        category = BookCategory.find_by(id: id, tenant_id: @tenant.id)
        raise Error, "Category was not found" unless category

        @book.book_category_assignments.create!(book_category: category)
      end
      @book.save! if @book.primary_category_id_changed?
    end

    def sync_genres
      @book.book_genres.destroy_all
      Array(@attrs[:genre_ids]).uniq.each do |id|
        genre = Genre.find_by(id: id, tenant_id: @tenant.id)
        raise Error, "Genre was not found" unless genre

        @book.book_genres.create!(genre: genre)
      end
    end

    def sync_metadata
      @book.metadata_entries.destroy_all
      Array(@attrs[:metadata]).each do |entry|
        @book.metadata_entries.create!(
          metadata_schema: entry[:schema],
          metadata_key: entry[:key],
          metadata_value: entry[:value].nil? ? {} : entry[:value]
        )
      end
    end

    def sync_editions
      raise Error, "Update editions through the editions endpoint" unless @creating

      Array(@attrs[:editions]).each do |entry|
        SaveEdition.new(tenant: @tenant, book: @book, attrs: entry).call
      end
    end
  end
end
