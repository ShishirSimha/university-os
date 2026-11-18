module CatalogueReferenceData
  LANGUAGES = [
    { code: "en", name: "English", native_name: "English" },
    { code: "hi", name: "Hindi", native_name: "हिन्दी" },
    { code: "kn", name: "Kannada", native_name: "ಕನ್ನಡ" },
    { code: "fr", name: "French", native_name: "Français" },
    { code: "de", name: "German", native_name: "Deutsch" },
    { code: "es", name: "Spanish", native_name: "Español" },
    { code: "ar", name: "Arabic", native_name: "العربية" },
    { code: "zh", name: "Chinese", native_name: "中文" },
    { code: "pt", name: "Portuguese", native_name: "Português" },
    { code: "ja", name: "Japanese", native_name: "日本語" },
    { code: "ru", name: "Russian", native_name: "Русский" },
    { code: "ta", name: "Tamil", native_name: "தமிழ்" },
    { code: "te", name: "Telugu", native_name: "తెలుగు" },
    { code: "ml", name: "Malayalam", native_name: "മലയാളം" },
    { code: "bn", name: "Bengali", native_name: "বাংলা" }
  ].freeze

  FORMATS = [
    { code: "HARDCOVER", name: "Hardcover" },
    { code: "PAPERBACK", name: "Paperback" },
    { code: "EBOOK", name: "E-book" },
    { code: "AUDIOBOOK", name: "Audiobook" },
    { code: "LARGE_PRINT", name: "Large print" },
    { code: "BRAILLE", name: "Braille" },
    { code: "OTHER", name: "Other" }
  ].freeze

  def self.reset!
    @seeded = false
  end

  def self.seed!
    return if @seeded
    return unless defined?(Language) && Language.table_exists? && BookFormat.table_exists?

    Language.reset_column_information
    BookFormat.reset_column_information

    LANGUAGES.each do |row|
      Language.find_or_create_by!(code: row[:code]) do |language|
        language.name = row[:name]
        language.native_name = row[:native_name]
        language.is_active = true
      end
    end

    FORMATS.each do |row|
      BookFormat.find_or_create_by!(code: row[:code]) do |format|
        format.name = row[:name]
        format.is_active = true
      end
    end

    @seeded = true
  end
end
