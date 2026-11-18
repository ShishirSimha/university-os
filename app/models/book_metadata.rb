class BookMetadata < ApplicationRecord
  self.table_name = "book_metadata"

  include TenantOwned

  belongs_to :book

  validates :metadata_schema, presence: true, length: { maximum: 100 }
  validates :metadata_key, presence: true, length: { maximum: 150 }
  validates :metadata_key, uniqueness: { scope: [ :book_id, :metadata_schema ] }

  before_validation :normalize_metadata

  def summary_json
    {
      id: id,
      schema: metadata_schema,
      key: metadata_key,
      value: metadata_value
    }
  end

  private

  def normalize_metadata
    self.tenant_id = book.tenant_id if book
    self.metadata_schema = metadata_schema.to_s.strip.presence
    self.metadata_key = metadata_key.to_s.strip.presence
  end
end
