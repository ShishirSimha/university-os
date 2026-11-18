class BookIdentifier < ApplicationRecord
  TYPES = %w[ISBN_10 ISBN_13 DOI OCLC LCCN OTHER].freeze

  include TenantOwned

  belongs_to :book_edition

  validates :identifier_type, inclusion: { in: TYPES }
  validates :identifier_value, presence: true, length: { maximum: 100 }
  validates :identifier_value, uniqueness: { scope: [ :tenant_id, :identifier_type ], message: "has already been taken for this institution" }
  validate :checksum_is_valid

  before_validation :normalize_identifier
  before_save :demote_other_primaries, if: :is_primary?

  def summary_json
    {
      id: id,
      type: identifier_type,
      value: identifier_value,
      primary: is_primary
    }
  end

  private

  def normalize_identifier
    self.tenant_id = book_edition.tenant_id if book_edition
    self.identifier_type = identifier_type.to_s.strip.upcase.presence
    raw = identifier_value.to_s.strip
    self.identifier_value = identifier_type&.start_with?("ISBN") ? Catalogue::Isbn.normalize(raw) : raw.presence
  end

  def checksum_is_valid
    return if identifier_value.blank?

    valid = case identifier_type
    when "ISBN_10" then Catalogue::Isbn.valid_isbn10?(identifier_value)
    when "ISBN_13" then Catalogue::Isbn.valid_isbn13?(identifier_value)
    else true
    end
    errors.add(:identifier_value, "is not a valid #{identifier_type}") unless valid
  end

  def demote_other_primaries
    BookIdentifier.where(book_edition_id: book_edition_id, is_primary: true).where.not(id: id).update_all(is_primary: false)
  end
end
