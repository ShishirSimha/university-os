module Catalogue
  class EditionParams
    MAP = {
      edition_number: %i[editionNumber edition_number],
      edition_title: %i[editionTitle edition_title],
      publication_date: %i[publicationDate publication_date],
      publication_year: %i[publicationYear publication_year],
      language_id: %i[languageId language_id],
      language_code: %i[languageCode language_code],
      format_id: %i[formatId format_id],
      format_code: %i[formatCode format_code],
      publisher_id: %i[publisherId publisher_id],
      page_count: %i[pageCount page_count],
      width_mm: %i[widthMm width_mm],
      height_mm: %i[heightMm height_mm],
      depth_mm: %i[depthMm depth_mm],
      weight_grams: %i[weightGrams weight_grams],
      volume_number: %i[volumeNumber volume_number],
      series_name: %i[seriesName series_name],
      description: %i[description editionDescription edition_description]
    }.freeze

    def initialize(params)
      @params = params
    end

    def to_h
      hash = params_hash
      attrs = {}
      MAP.each do |target, keys|
        key = keys.find { |candidate| hash.key?(candidate) }
        attrs[target] = hash[key] if key
      end
      attrs[:identifiers] = identifier_entries(hash[:identifiers]) if hash.key?(:identifiers)
      attrs
    end

    private

    def identifier_entries(raw)
      raise Error, "Identifiers must be a list" unless raw.is_a?(Array)

      raw.map do |identifier|
        item = entry_hash(identifier)
        {
          type: item[:type].presence || item[:identifierType].presence || item[:identifier_type],
          value: item[:value].presence || item[:identifierValue].presence || item[:identifier_value],
          primary: if item.key?(:primary)
                     item[:primary]
                   elsif item.key?(:isPrimary)
                     item[:isPrimary]
                   elsif item.key?(:is_primary)
                     item[:is_primary]
                   else
                     false
                   end
        }
      end
    end

    def entry_hash(entry)
      raise Error, "Each entry must be an object" unless entry.respond_to?(:to_unsafe_h) || entry.is_a?(Hash)

      hash = entry.respond_to?(:to_unsafe_h) ? entry.to_unsafe_h : entry.to_h
      hash.with_indifferent_access
    end

    def params_hash
      hash = if @params.respond_to?(:to_unsafe_h)
        @params.to_unsafe_h
      else
        @params.to_h
      end
      hash.with_indifferent_access
    end
  end
end
