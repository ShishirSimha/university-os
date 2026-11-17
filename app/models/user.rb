class User < ApplicationRecord
  ACCOUNT_TYPES = %w[user admin].freeze

  has_secure_password

  before_validation :normalize_registration_attributes

  validates :email,
    presence: true,
    length: { maximum: 255 },
    format: { with: URI::MailTo::EMAIL_REGEXP, allow_blank: true },
    uniqueness: { case_sensitive: false, allow_blank: true }
  validates :name, :country, :country_code, :state, :address, :phone_number, presence: true
  validates :account_type, inclusion: { in: ACCOUNT_TYPES, message: "must be user or admin" }
  validates :password, length: { minimum: 8 }, if: -> { password.present? }

  def registration_json
    {
      id: id,
      email: email,
      name: name,
      accountType: account_type,
      country: country,
      countryCode: country_code,
      state: state,
      address: address,
      phoneNumber: phone_number
    }
  end

  private

  def normalize_registration_attributes
    self.email = email.to_s.strip.downcase.presence
    self.name = name.to_s.strip.presence
    self.account_type = account_type.to_s.strip.downcase.presence
    self.country = country.to_s.strip.presence
    self.country_code = country_code.to_s.strip.presence
    self.state = state.to_s.strip.presence
    self.address = address.to_s.strip.presence
    self.phone_number = phone_number.to_s.strip.presence
  end
end
