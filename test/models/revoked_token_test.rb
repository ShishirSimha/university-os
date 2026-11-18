require "test_helper"

class RevokedTokenTest < ActiveSupport::TestCase
  test "revoked tokens table lives in the library schema" do
    schema = RevokedToken.connection.select_value(<<~SQL.squish)
      SELECT n.nspname
      FROM pg_class c
      JOIN pg_namespace n ON n.oid = c.relnamespace
      WHERE c.relname = 'revoked_tokens' AND c.relkind = 'r'
    SQL

    assert_equal "library", schema
  end
end
