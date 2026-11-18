require "test_helper"

class BookTest < ActiveSupport::TestCase
  test "catalogue tables live in the library schema" do
    schema = Book.connection.select_value(<<~SQL.squish)
      SELECT n.nspname
      FROM pg_class c
      JOIN pg_namespace n ON n.oid = c.relnamespace
      WHERE c.relname = 'books' AND c.relkind = 'r'
    SQL

    assert_equal "library", schema
  end

  test "published books cannot be deleted by the database" do
    trigger = Book.connection.select_value(<<~SQL.squish)
      SELECT t.tgname
      FROM pg_trigger t
      JOIN pg_class c ON c.oid = t.tgrelid
      JOIN pg_namespace n ON n.oid = c.relnamespace
      WHERE n.nspname = 'library'
        AND c.relname = 'books'
        AND t.tgname = 'prevent_published_book_delete'
        AND NOT t.tgisinternal
    SQL

    assert_equal "prevent_published_book_delete", trigger
  end

  test "loads shared languages and formats" do
    assert Language.exists?(code: "en")
    assert BookFormat.exists?(code: "PAPERBACK")
  end
end
