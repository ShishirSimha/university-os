require "test_helper"

class TenantTest < ActiveSupport::TestCase
  test "tenants table lives in the library schema" do
    schema = Tenant.connection.select_value(<<~SQL.squish)
      SELECT n.nspname
      FROM pg_class c
      JOIN pg_namespace n ON n.oid = c.relnamespace
      WHERE c.relname = 'tenants' AND c.relkind = 'r'
    SQL

    assert_equal "library", schema
  end

  test "normalizes the institution code and defaults status to active" do
    tenant = Tenant.new(name: "  ABC University  ", code: " abc ")

    assert tenant.valid?
    assert_equal "ABC University", tenant.name
    assert_equal "ABC", tenant.code
    assert_equal "active", tenant.status
    assert_predicate tenant, :active?
  end

  test "rejects a duplicate code and an unknown status" do
    create_institution(code: "ABC")
    duplicate = Tenant.new(name: "Another", code: "abc", status: "closed")

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:code], "has already been taken"
    assert_includes duplicate.errors[:status], "is not included in the list"
  end
end
