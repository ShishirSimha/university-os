class AuthorAlias < ApplicationRecord
  include TenantOwned

  belongs_to :author

  validates :name, presence: true, length: { maximum: 300 }, uniqueness: { scope: :author_id, case_sensitive: false }

  before_validation :normalize_alias

  private

  def normalize_alias
    self.name = name.to_s.strip.presence
    self.tenant_id = author.tenant_id if author
  end
end
