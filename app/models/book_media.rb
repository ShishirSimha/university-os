class BookMedia < ApplicationRecord
  self.table_name = "book_media"

  TYPES = %w[cover back_cover sample].freeze
  VARIANTS = %w[original large medium thumbnail].freeze
  MIME_TYPES = %w[image/jpeg image/png image/webp image/gif].freeze
  MAX_FILE_SIZE = 5.megabytes

  include TenantOwned

  belongs_to :book_edition
  belongs_to :uploader, class_name: "User", foreign_key: :uploaded_by, inverse_of: false

  validates :media_type, inclusion: { in: TYPES }
  validates :variant, inclusion: { in: VARIANTS }, allow_nil: true
  validates :storage_key, presence: true, length: { maximum: 500 }, format: { with: %r{\A[A-Za-z0-9/_.-]+\z} }
  validates :original_filename, length: { maximum: 255 }, allow_nil: true
  validates :mime_type, inclusion: { in: MIME_TYPES }
  validates :file_size, numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: MAX_FILE_SIZE }
  validates :alt_text, length: { maximum: 500 }, allow_nil: true
  validate :cover_has_alt_text

  before_validation :normalize_media
  before_save :demote_other_primaries, if: :is_primary?

  def summary_json
    {
      id: id,
      editionId: book_edition_id,
      mediaType: media_type,
      storageKey: storage_key,
      originalFilename: original_filename,
      mimeType: mime_type,
      fileSize: file_size,
      width: width,
      height: height,
      variant: variant,
      altText: alt_text,
      primary: is_primary
    }
  end

  private

  def normalize_media
    self.tenant_id = book_edition.tenant_id if book_edition
    self.media_type = media_type.to_s.strip.downcase.presence
    self.variant = variant.to_s.strip.downcase.presence
    self.mime_type = mime_type.to_s.strip.downcase.presence
    self.storage_key = storage_key.to_s.strip.presence
    self.original_filename = File.basename(original_filename.to_s).presence
    self.alt_text = alt_text.to_s.strip.presence
  end

  def cover_has_alt_text
    return unless %w[cover back_cover].include?(media_type)
    errors.add(:alt_text, "can't be blank") if alt_text.blank?
  end

  def demote_other_primaries
    BookMedia.where(book_edition_id: book_edition_id, media_type: media_type, is_primary: true).where.not(id: id).update_all(is_primary: false)
  end
end
