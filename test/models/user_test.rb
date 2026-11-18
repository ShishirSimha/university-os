require "test_helper"

class UserTest < ActiveSupport::TestCase
  setup do
    @tenant = create_institution
  end

  test "users table lives in the library schema" do
    schema = User.connection.select_value(<<~SQL.squish)
      SELECT n.nspname
      FROM pg_class c
      JOIN pg_namespace n ON n.oid = c.relnamespace
      WHERE c.relname = 'users' AND c.relkind = 'r'
    SQL

    assert_equal "library", schema
  end

  test "normalizes email and account type" do
    user = build_user(email: "  Test@Example.com ", account_type: " Admin ")
    assert user.valid?
    assert_equal "test@example.com", user.email
    assert_equal "admin", user.account_type
  end

  test "rejects an unknown account type" do
    user = build_user(account_type: "student")
    assert_not user.valid?
    assert_includes user.errors[:account_type], "must be user or admin"
  end

  test "stores a password digest" do
    user = build_user
    user.save!

    assert user.authenticate("password")
    assert_not_equal "password", user.password_digest
  end

  test "rejects a duplicate email ignoring case within the same institution" do
    build_user(email: "person@example.com").save!
    duplicate = build_user(email: "Person@Example.com")

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:email], "has already been taken"
  end

  test "allows the same email at another institution" do
    build_user(email: "person@example.com").save!
    other = build_user(email: "person@example.com", tenant: create_institution(code: "XYZ", name: "XYZ University"))

    assert other.valid?
  end

  test "requires an institution" do
    user = build_user(tenant: nil)

    assert_not user.valid?
    assert_includes user.errors[:tenant], "must exist"
  end

  private

  def build_user(overrides = {})
    User.new({
      email: "person@example.com",
      password: "password",
      name: "Test Name",
      account_type: "user",
      country: "Nigeria",
      country_code: "+123",
      state: "Rivers",
      address: "No. 6 Prince Okey",
      phone_number: "8124566736",
      tenant: @tenant
    }.merge(overrides))
  end
end
