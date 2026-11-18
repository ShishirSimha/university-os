module Catalogue
  class Isbn
    def self.normalize(value)
      value.to_s.gsub(/[^0-9Xx]/, "").upcase
    end

    def self.valid_isbn10?(value)
      digits = normalize(value)
      return false unless digits.match?(/\A\d{9}[\dX]\z/)

      sum = digits.chars.each_with_index.sum do |char, index|
        (char == "X" ? 10 : char.to_i) * (10 - index)
      end
      (sum % 11).zero?
    end

    def self.valid_isbn13?(value)
      digits = normalize(value)
      return false unless digits.match?(/\A97[89]\d{10}\z/)

      sum = digits.chars.each_with_index.sum do |char, index|
        weight = index.even? ? 1 : 3
        char.to_i * weight
      end
      (sum % 10).zero?
    end
  end
end
