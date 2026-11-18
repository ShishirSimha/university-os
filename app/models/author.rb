class Author < ApplicationRecord
  ORCID_FORMAT = /\A\d{4}-\d{4}-\d{4}-\d{3}[\dX]\z/

  include TenantOwned
  include ActiveArchived

  has_many :aliases, class_name: "AuthorAlias", dependent: :destroy
  has_many :book_authors, dependent: :restrict_with_error
  has_many :books, through: :book_authors
  has_many :edition_contributors, class_name: "BookEditionContributor", dependent: :restrict_with_error

  validates :display_name, presence: true, length: { maximum: 300 }
  validates :first_name, :middle_name, :last_name, length: { maximum: 150 }, allow_nil: true
  validates :orcid, format: { with: ORCID_FORMAT, allow_blank: true }
  validates :nationality_code, length: { maximum: 10 }, allow_nil: true

  before_validation :normalize_author
  after_update :record_author_change

  def reference_json
    {
      id: id,
      firstName: first_name,
      middleName: middle_name,
      lastName: last_name,
      displayName: display_name,
      biography: biography,
      orcid: orcid,
      nationalityCode: nationality_code,
      status: status,
      aliases: aliases.map(&:name)
    }
  end

  def related_books
    Book.where(id: related_book_ids)
  end

  private

  def related_book_ids
    book_ids = book_authors.pluck(:book_id)
    edition_ids = edition_contributors.pluck(:book_edition_id)
    book_ids + BookEdition.where(id: edition_ids).pluck(:book_id)
  end

  def record_author_change
    changes = saved_changes.except("created_at", "updated_at")
    return if changes.empty?

    Catalogue::Outbox.record!(
      tenant_id: tenant_id,
      event_name: "catalogue.author.updated",
      payload: { author_id: id, tenant_id: tenant_id }
    )
    Book.where(id: related_book_ids).find_each do |book|
      Catalogue::AuditRecorder.record!(
        book: book,
        action: "UPDATE",
        old_values: { author: changes.transform_values(&:first) },
        new_values: { author: changes.transform_values(&:last) }
      )
    end
  end

  def normalize_author
    self.first_name = first_name.to_s.strip.presence
    self.middle_name = middle_name.to_s.strip.presence
    self.last_name = last_name.to_s.strip.presence
    self.biography = biography.to_s.strip.presence
    self.orcid = orcid.to_s.strip.upcase.presence
    self.nationality_code = nationality_code.to_s.strip.upcase.presence
    composed = [ first_name, middle_name, last_name ].compact.join(" ")
    self.display_name = display_name.to_s.strip.presence || composed.presence
  end
end
