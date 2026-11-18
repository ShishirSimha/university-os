class Publisher < ApplicationRecord
  include TenantOwned
  include ActiveArchived

  has_many :editions, class_name: "BookEdition", dependent: :restrict_with_error

  validates :name, presence: true, length: { maximum: 255 }
  validates :website, length: { maximum: 500 }, format: { with: %r{\Ahttps?://}i, allow_blank: true }
  validates :email, length: { maximum: 255 }, format: { with: URI::MailTo::EMAIL_REGEXP, allow_blank: true }
  validates :country_code, length: { maximum: 10 }, allow_nil: true

  before_validation :normalize_publisher

  def reference_json
    {
      id: id,
      name: name,
      description: description,
      website: website,
      countryCode: country_code,
      email: email,
      status: status
    }
  end

  private

  def normalize_publisher
    self.name = name.to_s.strip.presence
    self.description = description.to_s.strip.presence
    self.website = website.to_s.strip.presence
    self.email = email.to_s.strip.downcase.presence
    self.country_code = country_code.to_s.strip.upcase.presence
  end
end
