class BookCategory < ApplicationRecord
  include TenantOwned
  include ActiveArchived

  belongs_to :parent, class_name: "BookCategory", optional: true
  has_many :children, class_name: "BookCategory", foreign_key: :parent_id, dependent: :restrict_with_error, inverse_of: :parent

  validates :name, presence: true, length: { maximum: 150 }
  validates :code, presence: true, length: { maximum: 100 }, uniqueness: { scope: :tenant_id, case_sensitive: false }
  validate :parent_is_valid

  before_validation :normalize_category

  def reference_json
    {
      id: id,
      name: name,
      code: code,
      description: description,
      status: status,
      parentId: parent_id
    }
  end

  private

  def normalize_category
    self.name = name.to_s.strip.presence
    self.code = code.to_s.strip.upcase.presence
    self.description = description.to_s.strip.presence
  end

  def parent_is_valid
    return if parent_id.blank?
    errors.add(:parent, "must belong to the same institution") if parent && parent.tenant_id != tenant_id
    current = parent
    visited = []
    while current
      if current.id == id || visited.include?(current.id)
        errors.add(:parent, "cannot create a cycle")
        break
      end
      visited << current.id
      current = current.parent
    end
  end
end
