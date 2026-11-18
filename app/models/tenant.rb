class Tenant < ApplicationRecord
  STATUSES = %w[active suspended].freeze
  CODE_FORMAT = /\A[A-Z0-9][A-Z0-9_-]{1,49}\z/

  has_many :users, dependent: :restrict_with_error

  before_validation :normalize_attributes

  validates :name, presence: true, length: { maximum: 255 }
  validates :code,
    presence: true,
    length: { maximum: 50 },
    uniqueness: { case_sensitive: false, allow_blank: true },
    format: { with: CODE_FORMAT, allow_blank: true, message: "must contain 2 to 50 letters, numbers, underscores, or hyphens" }
  validates :status, inclusion: { in: STATUSES }

  def self.human_attribute_name(attribute, options = {})
    return "Institution code" if attribute.to_sym == :code

    super
  end

  def active?
    status == "active"
  end

  def suspended?
    status == "suspended"
  end

  def institution_json
    {
      id: id,
      name: name,
      code: code,
      status: status
    }
  end

  private

  def normalize_attributes
    self.name = name.to_s.strip.presence
    self.code = code.to_s.strip.upcase.presence
    self.status = status.to_s.strip.downcase.presence || "active"
  end
end
