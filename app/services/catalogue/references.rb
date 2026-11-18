module Catalogue
  class References
    def self.language(id, code)
      return if id.blank? && code.blank?

      language = id.present? ? Language.find_by(id: id) : Language.find_by(code: code.to_s.strip.downcase)
      raise Error, "Language was not found" unless language&.active?

      language
    end

    def self.format(id, code)
      return if id.blank? && code.blank?

      format = id.present? ? BookFormat.find_by(id: id) : BookFormat.find_by(code: code.to_s.strip.upcase)
      raise Error, "Format was not found" unless format&.active?

      format
    end

    def self.publisher(id, tenant)
      return if id.blank?

      publisher = Publisher.find_by(id: id, tenant_id: tenant.id)
      raise Error, "Publisher was not found" unless publisher
      raise Error, "Publisher is archived" if publisher.archived?

      publisher
    end

    def self.date(value)
      return if value.blank?

      Date.iso8601(value.to_s)
    rescue Date::Error
      raise Error, "Publication date is invalid"
    end

    def self.year(value)
      return if value.blank?

      year = Integer(value, exception: false)
      raise Error, "Publication year is invalid" if year.nil?

      year
    end

    def self.integer(value, label)
      return if value.blank?

      number = Integer(value, exception: false)
      raise Error, "#{label} is invalid" if number.nil?

      number
    end
  end
end
