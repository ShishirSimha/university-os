module CatalogueGuards
  def self.install!
    return unless defined?(Book) && Book.table_exists?

    connection = Book.connection
    connection.execute(<<~SQL)
      CREATE OR REPLACE FUNCTION library.prevent_published_book_delete()
      RETURNS trigger
      LANGUAGE plpgsql
      AS $$
      BEGIN
        IF OLD.status IS DISTINCT FROM 'draft' THEN
          RAISE EXCEPTION 'Only draft books can be deleted';
        END IF;

        IF EXISTS (SELECT 1 FROM library.book_editions WHERE book_id = OLD.id) THEN
          RAISE EXCEPTION 'Drafts with editions cannot be deleted';
        END IF;

        RETURN OLD;
      END;
      $$;
    SQL
    connection.execute("DROP TRIGGER IF EXISTS prevent_published_book_delete ON library.books")
    connection.execute(<<~SQL)
      CREATE TRIGGER prevent_published_book_delete
      BEFORE DELETE ON library.books
      FOR EACH ROW
      EXECUTE FUNCTION library.prevent_published_book_delete()
    SQL
  end
end
