module Api
  module V1
    class CatalogueController < Api::BaseController
      before_action :authenticate_user!

      rescue_from ActiveRecord::StatementInvalid, with: :render_statement_invalid
      rescue_from ActiveRecord::RecordInvalid, with: :render_invalid_record
      rescue_from ActiveRecord::RecordNotDestroyed, with: :render_not_destroyed
      rescue_from ActiveRecord::RecordNotFound, with: :render_missing
      rescue_from ActiveRecord::InvalidForeignKey, with: :render_foreign_key
      rescue_from ActiveRecord::RecordNotUnique, with: :render_taken
      rescue_from Catalogue::Error, with: :render_catalogue_error

      private

      def require_catalogue_manager!
        return if current_user.admin?

        render_error("You are not allowed to manage the catalogue", status: :forbidden)
      end

      def render_data(message, data, status: :ok)
        render json: { status: Rack::Utils.status_code(status), message: message, data: data }, status: status
      end

      def render_page(message, key, relation, &block)
        total = relation.unscope(:order).count
        rows = relation.offset((page_number - 1) * page_size).limit(page_size)
        render_data(message, {
          key => rows.map { |row| block.call(row) },
          page: page_number,
          perPage: page_size,
          total: total
        })
      end

      def render_invalid_record(error)
        status = taken_error?(error.record) ? :conflict : :bad_request
        render_error(error.record.errors.full_messages.to_sentence, status: status)
      end

      def render_taken(_error)
        render_error("That value has already been taken", status: :conflict)
      end

      def render_not_destroyed(error)
        message = error.record.errors.full_messages.to_sentence
        render_error(message.presence || "The record could not be deleted", status: :conflict)
      end

      def render_missing(_error)
        render_error("Record not found", status: :not_found)
      end

      def render_foreign_key(_error)
        render_error("The record references something outside this institution", status: :bad_request)
      end

      def render_statement_invalid(error)
        cause = error.cause
        if cause.is_a?(PG::UniqueViolation)
          render_error("That value has already been taken", status: :conflict)
        elsif cause.is_a?(PG::ForeignKeyViolation)
          render_error("The record references something outside this institution", status: :bad_request)
        elsif cause.is_a?(PG::InvalidTextRepresentation)
          render_error("A referenced record was not found", status: :bad_request)
        elsif cause.is_a?(PG::NotNullViolation)
          render_error("A required value is missing", status: :bad_request)
        elsif cause.is_a?(PG::CheckViolation)
          render_error("The change violates a catalogue rule", status: :bad_request)
        elsif cause.is_a?(PG::RaiseException)
          message = cause.message.to_s.lines.first.to_s.sub(/\AERROR:\s*/, "").strip
          render_error(message.presence || "The record could not be deleted", status: :conflict)
        else
          raise error
        end
      end

      def render_catalogue_error(error)
        render_error(error.message, status: error.status)
      end

      def taken_error?(record)
        record.errors.details.values.flatten.any? { |detail| detail[:error] == :taken }
      end

      def tenant_books
        Book.where(tenant_id: current_tenant.id)
      end

      def visible_books
        return tenant_books if current_user.admin?

        tenant_books.where(status: "published")
      end

      def ensure_book_editable!(book)
        raise Catalogue::Error.new("Archived books cannot be edited", status: :conflict) if book.archived?
      end

      def ensure_edition_editable!(edition)
        ensure_book_editable!(edition.book)
        raise Catalogue::Error.new("Archived editions cannot be edited", status: :conflict) if edition.archived?
      end

      def page_number
        page = Integer(params[:page], exception: false) || 1
        page.positive? ? page : 1
      end

      def page_size
        raw = params[:perPage].presence || params[:per_page]
        size = Integer(raw, exception: false) || 20
        size = 20 unless size.positive?
        [ size, 100 ].min
      end

      def field(*keys)
        key = keys.find { |candidate| params.key?(candidate) }
        params[key] unless key.nil?
      end

      def field?(*keys)
        keys.any? { |key| params.key?(key) }
      end

      def boolean_field(*keys)
        key = keys.find { |candidate| params.key?(candidate) }
        return false if key.nil?

        ActiveModel::Type::Boolean.new.cast(params[key])
      end

      def like_term(value)
        "%#{ActiveRecord::Base.sanitize_sql_like(value.to_s.strip)}%"
      end

      def detailed_book(book)
        Book.preload(
          :original_language,
          :primary_category,
          :categories,
          :genres,
          :metadata_entries,
          book_authors: :author,
          book_subjects: :subject,
          editions: [ :publisher, :language, :format, :identifiers, :media, { contributors: :author } ]
        ).find(book.id).detail_json
      end
    end
  end
end
