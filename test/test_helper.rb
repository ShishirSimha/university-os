ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require "bcrypt"
require_relative "../db/catalogue_reference_data"
require_relative "../db/catalogue_guards"

BCrypt::Engine.cost = BCrypt::Engine::MIN_COST

CatalogueReferenceData.seed!
CatalogueGuards.install!

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    parallelize_setup do
      CatalogueReferenceData.reset!
      CatalogueReferenceData.seed!
      CatalogueGuards.install!
    end

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    def auth_headers(user)
      { "Authorization" => "Bearer #{JsonWebToken.encode(user.id, user.tenant_id)}" }
    end

    def create_institution(name: "ABC University", code: "ABC", status: "active")
      Tenant.create!(name: name, code: code, status: status)
    end

    def create_auth_user(tenant: nil, **overrides)
      tenant ||= create_institution
      User.create!({
        email: "test@test.com",
        password: "password",
        name: "Test Name",
        account_type: "user",
        country: "Nigeria",
        country_code: "+123",
        state: "Rivers",
        address: "No. 6 Prince Okey",
        phone_number: "8124566736",
        tenant: tenant
      }.merge(overrides))
    end
  end
end
