class Subject < ApplicationRecord
  SCHEMES = %w[DDC UDC LCC LOCAL].freeze

  include TenantOwned
  include ActiveArchived

  belongs_to :parent, class_name: "Subject", optional: true
  has_many :children, class_name: "Subject", foreign_key: :parent_id, dependent: :restrict_with_error, inverse_of: :parent

  validates :name, presence: true, length: { maximum: 255 }
  validates :code, presence: true, length: { maximum: 100 }
  validates :code, uniqueness: { scope: [ :tenant_id, :classification_scheme ], case_sensitive: false }
  validates :classification_scheme, inclusion: { in: SCHEMES }
  validates :external_identifier, length: { maximum: 150 }, allow_nil: true
  validate :parent_is_valid

  before_validation :normalize_subject

  def reference_json
    {
      id: id,
      name: name,
      code: code,
      classificationScheme: classification_scheme,
      externalIdentifier: external_identifier,
      description: description,
      status: status,
      parentId: parent_id
    }
  end

  private

  def normalize_subject
    self.name = name.to_s.strip.presence
    self.code = code.to_s.strip.upcase.presence
    self.classification_scheme = classification_scheme.to_s.strip.upcase.presence || "LOCAL"
    self.external_identifier = external_identifier.to_s.strip.presence
    self.description = description.to_s.strip.presence
  end

  def parent_is_valid
    return if parent_id.blank?
    errors.add(:parent, "must belong to the same institution") if parent && parent.tenant_id != tenant_id
    errors.add(:parent, "must use the same classification scheme") if parent && parent.classification_scheme != classification_scheme
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
