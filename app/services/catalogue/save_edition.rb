module Catalogue
  class SaveEdition
    def initialize(tenant:, book:, attrs:, edition: nil)
      @tenant = tenant
      @book = book
      @attrs = attrs
      @edition = edition
      @creating = edition.nil?
    end

    def call
      BookEdition.transaction do
        raise Error.new("Archived books cannot be edited", status: :conflict) if @book.archived?

        if @creating
          @edition = @book.editions.build
        elsif @edition.archived?
          raise Error.new("Archived editions cannot be edited", status: :conflict)
        end

        assign
        @edition.save!
        create_identifiers if @creating && @attrs.key?(:identifiers)
        @edition
      end
    end

    private

    def assign
      @edition.edition_number = @attrs[:edition_number] if @attrs.key?(:edition_number)
      @edition.edition_title = @attrs[:edition_title] if @attrs.key?(:edition_title)
      @edition.volume_number = @attrs[:volume_number] if @attrs.key?(:volume_number)
      @edition.series_name = @attrs[:series_name] if @attrs.key?(:series_name)
      @edition.edition_description = @attrs[:description] if @attrs.key?(:description)
      @edition.publication_date = References.date(@attrs[:publication_date]) if @attrs.key?(:publication_date)
      @edition.publication_year = References.year(@attrs[:publication_year]) if @attrs.key?(:publication_year)
      @edition.page_count = References.integer(@attrs[:page_count], "Page count") if @attrs.key?(:page_count)
      @edition.width_mm = References.integer(@attrs[:width_mm], "Width") if @attrs.key?(:width_mm)
      @edition.height_mm = References.integer(@attrs[:height_mm], "Height") if @attrs.key?(:height_mm)
      @edition.depth_mm = References.integer(@attrs[:depth_mm], "Depth") if @attrs.key?(:depth_mm)
      @edition.weight_grams = References.integer(@attrs[:weight_grams], "Weight") if @attrs.key?(:weight_grams)
      if @attrs.key?(:language_id) || @attrs.key?(:language_code)
        @edition.language = References.language(@attrs[:language_id], @attrs[:language_code])
      end
      if @attrs.key?(:format_id) || @attrs.key?(:format_code)
        @edition.format = References.format(@attrs[:format_id], @attrs[:format_code])
      end
      @edition.publisher = References.publisher(@attrs[:publisher_id], @tenant) if @attrs.key?(:publisher_id)
    end

    def create_identifiers
      Array(@attrs[:identifiers]).each do |identifier|
        @edition.identifiers.create!(
          identifier_type: identifier[:type],
          identifier_value: identifier[:value],
          is_primary: ActiveModel::Type::Boolean.new.cast(identifier[:primary]) || false
        )
      end
    end
  end
end
