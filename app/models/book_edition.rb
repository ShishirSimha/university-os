class BookEdition < ApplicationRecord
  include TenantOwned
  include ActiveArchived

  belongs_to :book
  belongs_to :publisher, optional: true
  belongs_to :language, optional: true
  belongs_to :format, class_name: "BookFormat", optional: true

  has_many :identifiers, class_name: "BookIdentifier", dependent: :destroy
  has_many :contributors, class_name: "BookEditionContributor", dependent: :destroy
  has_many :media, class_name: "BookMedia", dependent: :destroy

  attr_accessor :skip_catalogue_events

  validates :edition_number, length: { maximum: 50 }, allow_nil: true
  validates :edition_title, length: { maximum: 500 }, allow_nil: true
  validates :volume_number, length: { maximum: 50 }, allow_nil: true
  validates :series_name, length: { maximum: 255 }, allow_nil: true
  validates :page_count, :width_mm, :height_mm, :depth_mm, :weight_grams,
    numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validates :publication_year, numericality: { only_integer: true, in: 1..3000 }, allow_nil: true
  validate :references_are_assignable

  before_validation :normalize_edition
  before_destroy :detach_audit_logs
  after_create -> { record_edition_change("CREATE", "catalogue.edition.created") }
  after_update -> { record_edition_change("UPDATE", "catalogue.edition.updated") }

  def detail_json
    {
      id: id,
      editionNumber: edition_number,
      editionTitle: edition_title,
      publicationDate: publication_date,
      publicationYear: publication_year,
      language: language&.reference_json,
      format: format&.reference_json,
      publisher: publisher&.reference_json,
      pageCount: page_count,
      widthMm: width_mm,
      heightMm: height_mm,
      depthMm: depth_mm,
      weightGrams: weight_grams,
      volumeNumber: volume_number,
      seriesName: series_name,
      description: edition_description,
      status: status,
      translation: translated?,
      identifiers: identifiers.map(&:summary_json),
      contributors: contributors.sort_by(&:sequence_number).map(&:summary_json),
      media: media.map(&:summary_json)
    }
  end

  def inventory_summary
    {
      editionId: id,
      editionNumber: edition_number,
      totalCopies: nil,
      available: nil,
      onLoan: nil
    }
  end

  private

  def detach_audit_logs
    BookAuditLog.where(book_edition_id: id).update_all(book_edition_id: nil)
  end

  def normalize_edition
    self.tenant_id = book.tenant_id if book
    self.edition_number = edition_number.to_s.strip.presence
    self.edition_title = edition_title.to_s.strip.presence
    self.volume_number = volume_number.to_s.strip.presence
    self.series_name = series_name.to_s.strip.presence
    self.edition_description = edition_description.to_s.strip.presence
    self.publication_year ||= publication_date&.year
  end

  def translated?
    language_id.present? && book&.original_language_id.present? && language_id != book.original_language_id
  end

  def references_are_assignable
    if publisher && (new_record? || publisher_id_changed?)
      errors.add(:publisher, "must belong to the same institution") if publisher.tenant_id != tenant_id
      errors.add(:publisher, "is archived") if publisher.archived?
    end
    errors.add(:language, "is not active") if language && (new_record? || language_id_changed?) && !language.active?
    errors.add(:format, "is not active") if format && (new_record? || format_id_changed?) && !format.active?
  end

  def record_edition_change(action, event_name)
    return if skip_catalogue_events

    changes = saved_changes.except("created_at", "updated_at")
    return if action == "UPDATE" && changes.empty?

    Catalogue::AuditRecorder.record!(
      book: book,
      edition: self,
      action: action,
      old_values: changes.transform_values(&:first),
      new_values: changes.transform_values(&:last)
    )
    Catalogue::Outbox.record!(
      tenant_id: tenant_id,
      event_name: event_name,
      payload: { book_id: book_id, edition_id: id, tenant_id: tenant_id }
    )
  end
end
