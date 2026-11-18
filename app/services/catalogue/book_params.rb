module Catalogue
  class BookParams
    def initialize(params)
      @params = params
    end

    def to_h
      attrs = {}
      copy(attrs, :title, :title)
      copy(attrs, :subtitle, :subtitle)
      copy(attrs, :description, :description)
      copy(attrs, :work_type, :workType, :work_type)
      copy(attrs, :catalogue_number, :catalogueNumber, :catalogue_number)
      copy(attrs, :original_language_id, :originalLanguageId, :original_language_id)
      copy(attrs, :original_language_code, :originalLanguageCode, :original_language_code)
      copy(attrs, :primary_category_id, :primaryCategoryId, :primary_category_id)
      copy(attrs, :primary_subject_id, :primarySubjectId, :primary_subject_id)
      copy(attrs, :reason, :reason)
      attrs[:authors] = author_entries if sent?(:authors)
      attrs[:subject_ids] = id_list(:subjectIds, :subject_ids) if sent?(:subjectIds, :subject_ids)
      attrs[:category_ids] = id_list(:categoryIds, :category_ids) if sent?(:categoryIds, :category_ids)
      attrs[:genre_ids] = id_list(:genreIds, :genre_ids) if sent?(:genreIds, :genre_ids)
      attrs[:editions] = edition_entries if sent?(:editions)
      attrs[:metadata] = metadata_entries if sent?(:metadata)
      attrs
    end

    private

    def copy(attrs, target, *keys)
      return unless sent?(*keys)

      attrs[target] = raw(*keys)
    end

    def author_entries
      array_param(:authors).map do |entry|
        hash = entry_hash(entry)
        {
          author_id: hash[:authorId].presence || hash[:author_id],
          role: hash[:role].presence || hash[:contributorRole].presence || hash[:contributor_role],
          sequence: hash[:sequence].presence || hash[:sequenceNumber].presence || hash[:sequence_number]
        }
      end
    end

    def edition_entries
      array_param(:editions).map do |entry|
        EditionParams.new(entry_hash(entry)).to_h
      end
    end

    def metadata_entries
      array_param(:metadata).map do |entry|
        hash = entry_hash(entry)
        {
          schema: hash[:schema].presence || hash[:metadataSchema].presence || hash[:metadata_schema],
          key: hash[:key].presence || hash[:metadataKey].presence || hash[:metadata_key],
          value: if hash.key?(:value)
                   hash[:value]
                 elsif hash.key?(:metadataValue)
                   hash[:metadataValue]
                 else
                   hash[:metadata_value]
                 end
        }
      end
    end

    def id_list(*keys)
      array_param(*keys).map(&:to_s)
    end

    def array_param(*keys)
      value = raw(*keys)
      return [] if value.nil?
      raise Error, "#{keys.first.to_s.underscore.humanize} must be a list" unless value.is_a?(Array)

      value
    end

    def entry_hash(entry)
      raise Error, "Each entry must be an object" unless entry.respond_to?(:to_unsafe_h) || entry.is_a?(Hash)

      hash = entry.respond_to?(:to_unsafe_h) ? entry.to_unsafe_h : entry.to_h
      hash.with_indifferent_access
    end

    def sent?(*keys)
      keys.any? { |key| @params.key?(key) }
    end

    def raw(*keys)
      key = keys.find { |candidate| @params.key?(candidate) }
      @params[key]
    end
  end
end
