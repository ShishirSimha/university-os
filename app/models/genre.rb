class Genre < ApplicationRecord
  include TenantOwned
  include ActiveArchived

  validates :name, presence: true, length: { maximum: 150 }
  validates :code, presence: true, length: { maximum: 100 }, uniqueness: { scope: :tenant_id, case_sensitive: false }

  before_validation :normalize_genre

  def reference_json
    { id: id, name: name, code: code, status: status }
  end

  private

  def normalize_genre
    self.name = name.to_s.strip.presence
    self.code = code.to_s.strip.upcase.presence
  end
end
