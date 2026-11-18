module Catalogue
  class BookQuery
    def initialize(scope, params, tenant:, admin:)
      @scope = scope
      @params = params.respond_to?(:to_unsafe_h) ? params.to_unsafe_h : params.to_h
      @params = @params.with_indifferent_access
      @tenant = tenant
      @admin = admin
    end

    def call
      scope = @scope
      scope = filter_status(scope)
      scope = filter_title(scope)
      scope = filter_query(scope)
      scope = filter_author(scope)
      scope = filter_isbn(scope)
      scope = filter_publisher(scope)
      scope = filter_subject(scope)
      scope = filter_genre(scope)
      scope = filter_category(scope)
      scope = filter_year(scope)
      scope = filter_language(scope)
      scope = filter_format(scope)
      scope = filter_edition(scope)
      sort(scope)
    end

    private

    def filter_status(scope)
      raw = param(:status)
      return scope if raw.blank?

      status = raw.to_s.strip.downcase
      raise Error, "Status is invalid" unless Book::STATUSES.include?(status)
      raise Error.new("You are not allowed to view that catalogue status", status: :forbidden) if !@admin && status != "published"

      scope.where(status: status)
    end

    def filter_title(scope)
      term = param(:title)
      return scope if term.blank?

      if param(:titleMatch, :title_match).to_s.downcase == "exact"
        scope.where("lower(books.title) = ?", term.to_s.strip.downcase)
      else
        scope.where("books.title ILIKE ?", like_term(term))
      end
    end

    def filter_query(scope)
      term = param(:q)
      return scope if term.blank?

      like = like_term(term)
      normalized = Isbn.normalize(term)
      parts = []
      parts << Book.where(tenant_id: @tenant.id).where(
        "title ILIKE :q OR subtitle ILIKE :q OR COALESCE(description, '') ILIKE :q", q: like
      ).select(:id)
      parts << Book.where(tenant_id: @tenant.id, id: author_ids(like)).select(:id)
      parts << Book.where(tenant_id: @tenant.id, id: publisher_book_ids(like)).select(:id)
      parts << Book.where(tenant_id: @tenant.id, id: subject_book_ids(like)).select(:id)
      if normalized.present?
        parts << Book.where(tenant_id: @tenant.id, id: isbn_book_ids(normalized)).select(:id)
      end
      scope.where("books.id IN (#{parts.map { |part| "(#{part.to_sql})" }.join(' UNION ')})")
    end

    def filter_author(scope)
      term = param(:author)
      return scope if term.blank?

      scope.where(id: author_ids(like_term(term)))
    end

    def filter_isbn(scope)
      term = param(:isbn)
      return scope if term.blank?

      normalized = Isbn.normalize(term)
      return scope.none if normalized.blank?

      scope.where(id: isbn_book_ids(normalized, exact: true))
    end

    def filter_publisher(scope)
      term = param(:publisher)
      return scope if term.blank?

      scope.where(id: publisher_book_ids(like_term(term)))
    end

    def filter_subject(scope)
      term = param(:subject, :subjectId, :subject_id)
      return scope if term.blank?

      subjects = Subject.where(tenant_id: @tenant.id)
      subjects = uuid?(term) ? subjects.where(id: term) : subjects.where("name ILIKE :q OR code = :code", q: like_term(term), code: term.to_s.strip.upcase)
      scope.where(id: BookSubject.where(subject_id: subjects.select(:id)).select(:book_id))
    end

    def filter_genre(scope)
      term = param(:genre, :genreId, :genre_id)
      return scope if term.blank?

      genres = Genre.where(tenant_id: @tenant.id)
      genres = uuid?(term) ? genres.where(id: term) : genres.where("name ILIKE :q OR code = :code", q: like_term(term), code: term.to_s.strip.upcase)
      scope.where(id: BookGenre.where(genre_id: genres.select(:id)).select(:book_id))
    end

    def filter_category(scope)
      term = param(:category, :categoryId, :category_id)
      return scope if term.blank?

      categories = BookCategory.where(tenant_id: @tenant.id)
      categories = uuid?(term) ? categories.where(id: term) : categories.where("name ILIKE :q OR code = :code", q: like_term(term), code: term.to_s.strip.upcase)
      scope.where(id: BookCategoryAssignment.where(book_category_id: categories.select(:id)).select(:book_id))
    end

    def filter_year(scope)
      raw = param(:publicationYear, :publication_year, :year)
      return scope if raw.blank?

      year = Integer(raw, exception: false)
      raise Error, "Publication year is invalid" if year.nil?

      scope.where(id: BookEdition.where(tenant_id: @tenant.id, publication_year: year).select(:book_id))
    end

    def filter_language(scope)
      term = param(:language, :languageCode, :language_code, :languageId, :language_id)
      return scope if term.blank?

      language = uuid?(term) ? Language.find_by(id: term) : Language.find_by(code: term.to_s.strip.downcase)
      return scope.none if language.nil?

      edition_books = BookEdition.where(tenant_id: @tenant.id, language_id: language.id).select(:book_id)
      scope.where(original_language_id: language.id).or(scope.where(id: edition_books))
    end

    def filter_format(scope)
      term = param(:format, :formatCode, :format_code, :formatId, :format_id)
      return scope if term.blank?

      format = uuid?(term) ? BookFormat.find_by(id: term) : BookFormat.find_by(code: term.to_s.strip.upcase)
      return scope.none if format.nil?

      scope.where(id: BookEdition.where(tenant_id: @tenant.id, format_id: format.id).select(:book_id))
    end

    def filter_edition(scope)
      term = param(:edition, :editionNumber, :edition_number)
      return scope if term.blank?

      scope.where(id: BookEdition.where(tenant_id: @tenant.id).where("edition_number ILIKE ?", like_term(term)).select(:book_id))
    end

    def sort(scope)
      requested = param(:direction).to_s.downcase
      sort_key = param(:sort).to_s
      direction = if requested == "desc"
        "DESC"
      elsif requested == "asc"
        "ASC"
      elsif %w[created_at createdAt recent].include?(sort_key)
        "DESC"
      else
        "ASC"
      end
      sql = case sort_key
      when "author"
        "(SELECT MIN(authors.display_name) FROM book_authors INNER JOIN authors ON authors.id = book_authors.author_id WHERE book_authors.book_id = books.id) #{direction} NULLS LAST"
      when "publication_year", "publicationYear", "year"
        "(SELECT MIN(book_editions.publication_year) FROM book_editions WHERE book_editions.book_id = books.id) #{direction} NULLS LAST"
      when "created_at", "createdAt", "recent"
        "books.created_at #{direction}"
      else
        "books.title #{direction}"
      end
      scope.order(Arel.sql(sql))
    end

    def author_ids(like)
      authors = Author.where(tenant_id: @tenant.id).left_joins(:aliases).where(
        "authors.display_name ILIKE :q OR authors.first_name ILIKE :q OR authors.last_name ILIKE :q OR author_aliases.name ILIKE :q",
        q: like
      ).select(:id)
      BookAuthor.where(author_id: authors).select(:book_id)
    end

    def publisher_book_ids(like)
      publishers = Publisher.where(tenant_id: @tenant.id).where("name ILIKE ?", like).select(:id)
      BookEdition.where(publisher_id: publishers).select(:book_id)
    end

    def subject_book_ids(like)
      subjects = Subject.where(tenant_id: @tenant.id).where("name ILIKE :q OR code = :code", q: like, code: like.delete("%").upcase).select(:id)
      BookSubject.where(subject_id: subjects).select(:book_id)
    end

    def isbn_book_ids(normalized, exact: false)
      identifiers = BookIdentifier.where(tenant_id: @tenant.id)
      identifiers = if exact
        identifiers.where(identifier_value: normalized)
      else
        identifiers.where("identifier_value ILIKE ?", "%#{ActiveRecord::Base.sanitize_sql_like(normalized)}%")
      end
      BookEdition.where(id: identifiers.select(:book_edition_id)).select(:book_id)
    end

    def param(*keys)
      keys.each do |key|
        value = @params[key]
        return value if value.present?
      end
      nil
    end

    def like_term(value)
      "%#{ActiveRecord::Base.sanitize_sql_like(value.to_s.strip)}%"
    end

    def uuid?(value)
      value.to_s.match?(/\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i)
    end
  end
end
