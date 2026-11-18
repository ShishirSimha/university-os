class Language < ApplicationRecord
  include UuidPrimaryKey

  validates :code, presence: true, uniqueness: { case_sensitive: false }, length: { maximum: 10 }
  validates :name, presence: true, length: { maximum: 100 }
  validates :native_name, length: { maximum: 100 }, allow_nil: true

  before_validation :normalize_language

  scope :active, -> { where(is_active: true) }

  def active?
    is_active?
  end

  def reference_json
    { id: id, code: code, name: name, nativeName: native_name }
  end

  private

  def normalize_language
    self.code = code.to_s.strip.downcase.presence
    self.name = name.to_s.strip.presence
    self.native_name = native_name.to_s.strip.presence
  end
end
