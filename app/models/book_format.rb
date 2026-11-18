class BookFormat < ApplicationRecord
  include UuidPrimaryKey

  validates :code, presence: true, uniqueness: { case_sensitive: false }, length: { maximum: 50 }
  validates :name, presence: true, length: { maximum: 100 }

  before_validation :normalize_format

  scope :active, -> { where(is_active: true) }

  def active?
    is_active?
  end

  def reference_json
    { id: id, code: code, name: name, description: description }
  end

  private

  def normalize_format
    self.code = code.to_s.strip.upcase.presence
    self.name = name.to_s.strip.presence
    self.description = description.to_s.strip.presence
  end
end
