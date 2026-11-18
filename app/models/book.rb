class Book < ApplicationRecord
  STATUSES = %w[draft under_review published archived rejected withdrawn].freeze
  WORK_TYPES = %w[book textbook reference_work thesis other].freeze
  TRANSITIONS = {
    "draft" => %w[under_review published],
    "under_review" => %w[published rejected draft],
    "rejected" => %w[draft under_review],
    "published" => %w[archived withdrawn],
    "withdrawn" => %w[archived],
    "archived" => []
  }.freeze
  AUDIT_IGNORED = %w[created_at updated_at].freeze

  include TenantOwned

  belongs_to :original_language, class_name: "Language", optional: true
  belongs_to :primary_category, class_name: "BookCategory", optional: true
  belongs_to :creator, class_name: "User", foreign_key: :created_by, inverse_of: false
  belongs_to :editor, class_name: "User", foreign_key: :updated_by, inverse_of: false

  has_many :editions, class_name: "BookEdition", dependent: :restrict_with_error
  has_many :book_authors, dependent: :destroy
  has_many :authors, through: :book_authors
  has_many :book_subjects, dependent: :destroy
  has_many :subjects, through: :book_subjects
  has_many :book_category_assignments, dependent: :destroy
  has_many :categories, through: :book_category_assignments, source: :book_category
  has_many :book_genres, dependent: :destroy
  has_many :genres, through: :book_genres
  has_many :metadata_entries, class_name: "BookMetadata", dependent: :destroy
  has_many :audit_logs, class_name: "BookAuditLog", dependent: :delete_all

  attr_accessor :audit_actor, :audit_reason, :skip_catalogue_events

  validates :title, presence: true, length: { maximum: 500 }
  validates :subtitle, length: { maximum: 500 }, allow_nil: true
  validates :description, length: { maximum: 20_000 }, allow_nil: true
  validates :work_type, inclusion: { in: WORK_TYPES }
  validates :status, inclusion: { in: STATUSES }
  validates :catalogue_number, length: { maximum: 100 }, uniqueness: { scope: :tenant_id, allow_nil: true }
  validate :language_is_active, if: -> { original_language_id.present? && (new_record? || original_language_id_changed?) }
  validate :category_is_assignable, if: -> { primary_category_id.present? && (new_record? || primary_category_id_changed?) }

  before_validation :normalize_book
  before_destroy :ensure_deletable, prepend: true
  after_create :record_create
  after_update :record_update

  def draft?
    status == "draft"
  end

  def published?
    status == "published"
  end

  def archived?
    status == "archived"
  end

  def editable?
    !archived?
  end

  def deletable?
    draft? && !editions.exists?
  end

  def transition_to!(new_status)
    with_lock do
      unless TRANSITIONS.fetch(status).include?(new_status)
        raise Catalogue::Error.new("Cannot change status from #{status} to #{new_status}", status: :conflict)
      end

      attributes = { status: new_status, updated_by: Current.user&.id || updated_by }
      attributes[:published_at] = Time.current if new_status == "published"
      attributes[:archived_at] = Time.current if new_status == "archived"
      update!(attributes)
    end
  end

  # Loans and reservations belong to Circulation. Archiving catalogue metadata
  # does not change those records; this projection stays empty until Inventory reports.
  def circulation_warnings
    []
  end

  def summary_json
    {
      id: id,
      title: title,
      subtitle: subtitle,
      workType: work_type,
      status: status,
      catalogueNumber: catalogue_number,
      originalLanguage: original_language&.reference_json,
      authors: book_authors.sort_by(&:sequence_number).map(&:summary_json),
      editionCount: editions.size,
      publishedAt: published_at,
      createdAt: created_at,
      updatedAt: updated_at
    }
  end

  def detail_json
    summary_json.merge(
      description: description,
      primaryCategory: primary_category&.reference_json,
      categories: categories.map(&:reference_json),
      subjects: book_subjects.map(&:summary_json),
      genres: genres.map(&:reference_json),
      editions: editions.map(&:detail_json),
      metadata: metadata_entries.map(&:summary_json),
      inventorySummary: editions.map(&:inventory_summary),
      archivedAt: archived_at
    )
  end

  private

  def normalize_book
    self.title = title.to_s.strip.presence
    self.subtitle = subtitle.to_s.strip.presence
    self.description = description.to_s.strip.presence
    self.catalogue_number = catalogue_number.to_s.strip.presence
    self.work_type = work_type.to_s.strip.downcase.presence || "book"
    self.status = status.to_s.strip.downcase.presence || "draft"
  end

  def language_is_active
    errors.add(:original_language, "is not active") if original_language && !original_language.active?
  end

  def category_is_assignable
    return if primary_category.blank?
    errors.add(:primary_category, "must belong to the same institution") if primary_category.tenant_id != tenant_id
    errors.add(:primary_category, "is archived") if primary_category.archived?
  end

  def ensure_deletable
    return if deletable?

    errors.add(:base, "Only unused drafts can be deleted")
    throw :abort
  end

  def record_create
    record_catalogue_change("CREATE", "catalogue.book.created")
  end

  def record_update
    action, event_name = if saved_change_to_status? && status == "published"
      [ "PUBLISH", "catalogue.book.published" ]
    elsif saved_change_to_status? && status == "archived"
      [ "ARCHIVE", "catalogue.book.archived" ]
    elsif saved_change_to_status? && status == "under_review"
      [ "SUBMIT", "catalogue.book.updated" ]
    elsif saved_change_to_status? && status == "rejected"
      [ "REJECT", "catalogue.book.updated" ]
    elsif saved_change_to_status? && status == "withdrawn"
      [ "WITHDRAW", "catalogue.book.updated" ]
    else
      [ "UPDATE", "catalogue.book.updated" ]
    end
    record_catalogue_change(action, event_name)
  end

  def record_catalogue_change(action, event_name)
    return if skip_catalogue_events

    changes = saved_changes.except(*AUDIT_IGNORED)
    return if action != "CREATE" && changes.empty?

    Catalogue::AuditRecorder.record!(
      book: self,
      action: action,
      old_values: changes.transform_values(&:first),
      new_values: changes.transform_values(&:last),
      reason: audit_reason
    )
    Catalogue::Outbox.record!(
      tenant_id: tenant_id,
      event_name: event_name,
      payload: { book_id: id, tenant_id: tenant_id, status: status }
    )
  end
end
