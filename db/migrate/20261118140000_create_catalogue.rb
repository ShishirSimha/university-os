class CreateCatalogue < ActiveRecord::Migration[8.1]
  def up
    execute "CREATE SCHEMA IF NOT EXISTS library"
    execute "SET search_path TO library, public"
    enable_extension "pg_trgm" unless extension_enabled?("pg_trgm")

    create_languages
    create_book_formats
    expand_authors
    create_publishers
    create_classifications
    create_books
    create_editions
    create_identifiers
    create_contributor_links
    create_subject_links
    create_media
    create_metadata
    create_audit_logs
    create_outbox
    create_search_indexes

    require Rails.root.join("db/catalogue_reference_data")
    require Rails.root.join("db/catalogue_guards")
    CatalogueReferenceData.seed!
    CatalogueGuards.install!
  ensure
    execute "SET search_path TO library"
  end

  def down
    execute "SET search_path TO library"
    execute "DROP TRIGGER IF EXISTS prevent_published_book_delete ON books"
    execute "DROP FUNCTION IF EXISTS library.prevent_published_book_delete()"
    drop_table :catalogue_outbox_events, if_exists: true
    drop_table :book_audit_logs, if_exists: true
    drop_table :book_metadata, if_exists: true
    drop_table :book_media, if_exists: true
    drop_table :book_genres, if_exists: true
    drop_table :book_category_assignments, if_exists: true
    drop_table :book_subjects, if_exists: true
    drop_table :book_edition_contributors, if_exists: true
    drop_table :book_authors, if_exists: true
    drop_table :book_identifiers, if_exists: true
    drop_table :book_editions, if_exists: true
    drop_table :books, if_exists: true
    drop_table :genres, if_exists: true
    drop_table :subjects, if_exists: true
    drop_table :book_categories, if_exists: true
    drop_table :publishers, if_exists: true
    drop_table :author_aliases, if_exists: true
    if table_exists?(:authors) && column_exists?(:authors, :tenant_id)
      remove_foreign_key :authors, :tenants if foreign_key_exists?(:authors, :tenants)
      remove_column :authors, :tenant_id
      remove_column :authors, :middle_name
      remove_column :authors, :display_name
      remove_column :authors, :biography
      remove_column :authors, :orcid
      remove_column :authors, :nationality_code
      remove_column :authors, :status
    end
    drop_table :book_formats, if_exists: true
    drop_table :languages, if_exists: true
  end

  private

  def create_languages
    create_table :languages, id: :uuid do |t|
      t.string :code, null: false, limit: 10
      t.string :name, null: false, limit: 100
      t.string :native_name, limit: 100
      t.boolean :is_active, null: false, default: true
      t.timestamps
    end
    add_index :languages, :code, unique: true
  end

  def create_book_formats
    create_table :book_formats, id: :uuid do |t|
      t.string :code, null: false, limit: 50
      t.string :name, null: false, limit: 100
      t.text :description
      t.boolean :is_active, null: false, default: true
      t.timestamps
    end
    add_index :book_formats, :code, unique: true
  end

  def expand_authors
    change_column :authors, :first_name, :string, limit: 150
    change_column :authors, :last_name, :string, limit: 150
    add_column :authors, :tenant_id, :uuid
    add_column :authors, :middle_name, :string, limit: 150
    add_column :authors, :display_name, :string, limit: 300
    add_column :authors, :biography, :text
    add_column :authors, :orcid, :string, limit: 50
    add_column :authors, :nationality_code, :string, limit: 10
    add_column :authors, :status, :string, limit: 30, default: "active"

    execute <<~SQL.squish
      UPDATE authors
      SET display_name = COALESCE(NULLIF(btrim(concat_ws(' ', first_name, last_name)), ''), 'Unknown')
      WHERE display_name IS NULL OR btrim(display_name) = ''
    SQL
    backfill_author_tenants

    change_column_null :authors, :tenant_id, false
    change_column_null :authors, :display_name, false
    change_column_null :authors, :status, false
    add_foreign_key :authors, :tenants
    add_index :authors, [ :tenant_id, :id ], unique: true, name: "index_authors_on_tenant_id_and_id"
    add_index :authors, [ :tenant_id, :display_name ], name: "index_authors_on_tenant_id_and_display_name"
    add_check_constraint :authors, "status IN ('active', 'archived')", name: "authors_status_check"

    create_table :author_aliases, id: :uuid do |t|
      t.uuid :tenant_id, null: false
      t.uuid :author_id, null: false
      t.string :name, null: false, limit: 300
      t.timestamps
    end
    add_index :author_aliases, [ :tenant_id, :id ], unique: true, name: "index_author_aliases_on_tenant_id_and_id"
    add_index :author_aliases, "author_id, lower(name)", unique: true, name: "index_author_aliases_on_author_id_and_lower_name"
    add_foreign_key :author_aliases, :authors, column: [ :tenant_id, :author_id ], primary_key: [ :tenant_id, :id ], name: "fk_author_aliases_author"
    add_foreign_key :author_aliases, :tenants
  end

  def backfill_author_tenants
    return if select_value("SELECT COUNT(*) FROM authors WHERE tenant_id IS NULL").to_i.zero?

    tenant_id = select_value("SELECT id FROM tenants ORDER BY created_at LIMIT 1")
    if tenant_id.nil?
      execute <<~SQL.squish
        INSERT INTO tenants (id, name, code, status, created_at, updated_at)
        VALUES (gen_random_uuid(), 'Legacy Institution', 'LEGACY', 'active', NOW(), NOW())
      SQL
      tenant_id = select_value("SELECT id FROM tenants WHERE code = 'LEGACY'")
    end
    execute "UPDATE authors SET tenant_id = #{quote(tenant_id)} WHERE tenant_id IS NULL"
  end

  def create_publishers
    create_table :publishers, id: :uuid do |t|
      t.uuid :tenant_id, null: false
      t.string :name, null: false, limit: 255
      t.text :description
      t.string :website, limit: 500
      t.string :country_code, limit: 10
      t.string :email, limit: 255
      t.string :status, null: false, default: "active", limit: 30
      t.timestamps
    end
    add_index :publishers, [ :tenant_id, :id ], unique: true, name: "index_publishers_on_tenant_id_and_id"
    add_index :publishers, [ :tenant_id, :name ], name: "index_publishers_on_tenant_id_and_name"
    add_foreign_key :publishers, :tenants
    add_check_constraint :publishers, "status IN ('active', 'archived')", name: "publishers_status_check"
  end

  def create_classifications
    create_table :book_categories, id: :uuid do |t|
      t.uuid :tenant_id, null: false
      t.uuid :parent_id
      t.string :name, null: false, limit: 150
      t.string :code, null: false, limit: 100
      t.text :description
      t.string :status, null: false, default: "active", limit: 30
      t.timestamps
    end
    add_index :book_categories, [ :tenant_id, :id ], unique: true, name: "index_book_categories_on_tenant_id_and_id"
    add_index :book_categories, [ :tenant_id, :code ], unique: true, name: "index_book_categories_on_tenant_id_and_code"
    add_foreign_key :book_categories, :tenants
    add_foreign_key :book_categories, :book_categories, column: [ :tenant_id, :parent_id ], primary_key: [ :tenant_id, :id ], name: "fk_book_categories_parent"
    add_check_constraint :book_categories, "status IN ('active', 'archived')", name: "book_categories_status_check"
    add_check_constraint :book_categories, "parent_id IS NULL OR parent_id <> id", name: "book_categories_parent_check"

    create_table :subjects, id: :uuid do |t|
      t.uuid :tenant_id, null: false
      t.uuid :parent_id
      t.string :name, null: false, limit: 255
      t.string :code, null: false, limit: 100
      t.string :classification_scheme, null: false, default: "LOCAL", limit: 50
      t.string :external_identifier, limit: 150
      t.text :description
      t.string :status, null: false, default: "active", limit: 30
      t.timestamps
    end
    add_index :subjects, [ :tenant_id, :id ], unique: true, name: "index_subjects_on_tenant_id_and_id"
    add_index :subjects, [ :tenant_id, :classification_scheme, :code ], unique: true, name: "index_subjects_on_tenant_scheme_and_code"
    add_foreign_key :subjects, :tenants
    add_foreign_key :subjects, :subjects, column: [ :tenant_id, :parent_id ], primary_key: [ :tenant_id, :id ], name: "fk_subjects_parent"
    add_check_constraint :subjects, "classification_scheme IN ('DDC', 'UDC', 'LCC', 'LOCAL')", name: "subjects_scheme_check"
    add_check_constraint :subjects, "status IN ('active', 'archived')", name: "subjects_status_check"
    add_check_constraint :subjects, "parent_id IS NULL OR parent_id <> id", name: "subjects_parent_check"

    create_table :genres, id: :uuid do |t|
      t.uuid :tenant_id, null: false
      t.string :name, null: false, limit: 150
      t.string :code, null: false, limit: 100
      t.string :status, null: false, default: "active", limit: 30
      t.timestamps
    end
    add_index :genres, [ :tenant_id, :id ], unique: true, name: "index_genres_on_tenant_id_and_id"
    add_index :genres, [ :tenant_id, :code ], unique: true, name: "index_genres_on_tenant_id_and_code"
    add_foreign_key :genres, :tenants
    add_check_constraint :genres, "status IN ('active', 'archived')", name: "genres_status_check"
  end

  def create_books
    create_table :books, id: :uuid do |t|
      t.uuid :tenant_id, null: false
      t.string :title, null: false, limit: 500
      t.string :subtitle, limit: 500
      t.text :description
      t.uuid :original_language_id
      t.uuid :primary_category_id
      t.string :work_type, null: false, default: "book", limit: 50
      t.string :status, null: false, default: "draft", limit: 30
      t.string :catalogue_number, limit: 100
      t.bigint :created_by, null: false
      t.bigint :updated_by, null: false
      t.datetime :published_at
      t.datetime :archived_at
      t.timestamps
    end
    add_index :books, [ :tenant_id, :id ], unique: true, name: "index_books_on_tenant_id_and_id"
    add_index :books, [ :tenant_id, :status ], name: "index_books_on_tenant_id_and_status"
    add_index :books, [ :tenant_id, :title ], name: "index_books_on_tenant_id_and_title"
    add_index :books, [ :tenant_id, :created_at ], name: "index_books_on_tenant_id_and_created_at"
    add_index :books, [ :tenant_id, :catalogue_number ], unique: true, where: "catalogue_number IS NOT NULL", name: "index_books_on_tenant_id_and_catalogue_number"
    add_foreign_key :books, :tenants
    add_foreign_key :books, :languages, column: :original_language_id
    add_foreign_key :books, :book_categories, column: [ :tenant_id, :primary_category_id ], primary_key: [ :tenant_id, :id ], name: "fk_books_primary_category"
    add_foreign_key :books, :users, column: :created_by
    add_foreign_key :books, :users, column: :updated_by
    add_check_constraint :books, "status IN ('draft', 'under_review', 'published', 'archived', 'rejected', 'withdrawn')", name: "books_status_check"
    add_check_constraint :books, "work_type IN ('book', 'textbook', 'reference_work', 'thesis', 'other')", name: "books_work_type_check"
  end

  def create_editions
    create_table :book_editions, id: :uuid do |t|
      t.uuid :tenant_id, null: false
      t.uuid :book_id, null: false
      t.uuid :publisher_id
      t.string :edition_number, limit: 50
      t.string :edition_title, limit: 500
      t.date :publication_date
      t.integer :publication_year
      t.uuid :language_id
      t.uuid :format_id
      t.integer :page_count
      t.integer :width_mm
      t.integer :height_mm
      t.integer :depth_mm
      t.integer :weight_grams
      t.string :volume_number, limit: 50
      t.string :series_name, limit: 255
      t.text :edition_description
      t.string :status, null: false, default: "active", limit: 30
      t.timestamps
    end
    add_index :book_editions, [ :tenant_id, :id ], unique: true, name: "index_book_editions_on_tenant_id_and_id"
    add_index :book_editions, [ :tenant_id, :book_id ], name: "index_book_editions_on_tenant_id_and_book_id"
    add_foreign_key :book_editions, :tenants
    add_foreign_key :book_editions, :books, column: [ :tenant_id, :book_id ], primary_key: [ :tenant_id, :id ], name: "fk_book_editions_book"
    add_foreign_key :book_editions, :publishers, column: [ :tenant_id, :publisher_id ], primary_key: [ :tenant_id, :id ], name: "fk_book_editions_publisher"
    add_foreign_key :book_editions, :languages, column: :language_id
    add_foreign_key :book_editions, :book_formats, column: :format_id
    add_check_constraint :book_editions, "status IN ('active', 'archived')", name: "book_editions_status_check"
    add_check_constraint :book_editions, "page_count IS NULL OR page_count > 0", name: "book_editions_page_count_check"
    add_check_constraint :book_editions, "publication_year IS NULL OR publication_year BETWEEN 1 AND 3000", name: "book_editions_year_check"
  end

  def create_identifiers
    create_table :book_identifiers, id: :uuid do |t|
      t.uuid :tenant_id, null: false
      t.uuid :book_edition_id, null: false
      t.string :identifier_type, null: false, limit: 30
      t.string :identifier_value, null: false, limit: 100
      t.boolean :is_primary, null: false, default: false
      t.timestamps
    end
    add_index :book_identifiers, [ :tenant_id, :identifier_type, :identifier_value ], unique: true, name: "index_book_identifiers_on_tenant_type_and_value"
    add_index :book_identifiers, [ :tenant_id, :identifier_value ], name: "index_book_identifiers_on_tenant_id_and_value"
    add_index :book_identifiers, :book_edition_id, where: "is_primary", unique: true, name: "index_book_identifiers_one_primary"
    add_foreign_key :book_identifiers, :tenants
    add_foreign_key :book_identifiers, :book_editions, column: [ :tenant_id, :book_edition_id ], primary_key: [ :tenant_id, :id ], name: "fk_book_identifiers_edition"
    add_check_constraint :book_identifiers, "identifier_type IN ('ISBN_10', 'ISBN_13', 'DOI', 'OCLC', 'LCCN', 'OTHER')", name: "book_identifiers_type_check"
  end

  def create_contributor_links
    create_table :book_authors, id: :uuid do |t|
      t.uuid :tenant_id, null: false
      t.uuid :book_id, null: false
      t.uuid :author_id, null: false
      t.string :contributor_role, null: false, limit: 50
      t.integer :sequence_number, null: false, default: 1
      t.timestamps
    end
    add_index :book_authors, [ :book_id, :author_id, :contributor_role ], unique: true, name: "index_book_authors_on_book_author_and_role"
    add_index :book_authors, [ :book_id, :sequence_number ], name: "index_book_authors_on_book_id_and_sequence_number"
    add_foreign_key :book_authors, :tenants
    add_foreign_key :book_authors, :books, column: [ :tenant_id, :book_id ], primary_key: [ :tenant_id, :id ], name: "fk_book_authors_book"
    add_foreign_key :book_authors, :authors, column: [ :tenant_id, :author_id ], primary_key: [ :tenant_id, :id ], name: "fk_book_authors_author"
    add_check_constraint :book_authors, "contributor_role IN ('author', 'co_author', 'editor', 'translator', 'illustrator', 'compiler', 'contributor')", name: "book_authors_role_check"
    add_check_constraint :book_authors, "sequence_number > 0", name: "book_authors_sequence_check"

    create_table :book_edition_contributors, id: :uuid do |t|
      t.uuid :tenant_id, null: false
      t.uuid :book_edition_id, null: false
      t.uuid :author_id, null: false
      t.string :contributor_role, null: false, limit: 50
      t.integer :sequence_number, null: false, default: 1
      t.timestamps
    end
    add_index :book_edition_contributors, [ :book_edition_id, :author_id, :contributor_role ], unique: true, name: "index_edition_contributors_on_edition_author_and_role"
    add_foreign_key :book_edition_contributors, :tenants
    add_foreign_key :book_edition_contributors, :book_editions, column: [ :tenant_id, :book_edition_id ], primary_key: [ :tenant_id, :id ], name: "fk_edition_contributors_edition"
    add_foreign_key :book_edition_contributors, :authors, column: [ :tenant_id, :author_id ], primary_key: [ :tenant_id, :id ], name: "fk_edition_contributors_author"
    add_check_constraint :book_edition_contributors, "contributor_role IN ('author', 'co_author', 'editor', 'translator', 'illustrator', 'compiler', 'contributor')", name: "edition_contributors_role_check"
    add_check_constraint :book_edition_contributors, "sequence_number > 0", name: "edition_contributors_sequence_check"
  end

  def create_subject_links
    create_table :book_subjects, id: :uuid do |t|
      t.uuid :tenant_id, null: false
      t.uuid :book_id, null: false
      t.uuid :subject_id, null: false
      t.boolean :is_primary, null: false, default: false
      t.timestamps
    end
    add_index :book_subjects, [ :book_id, :subject_id ], unique: true, name: "index_book_subjects_on_book_id_and_subject_id"
    add_index :book_subjects, :book_id, where: "is_primary", unique: true, name: "index_book_subjects_one_primary"
    add_foreign_key :book_subjects, :tenants
    add_foreign_key :book_subjects, :books, column: [ :tenant_id, :book_id ], primary_key: [ :tenant_id, :id ], name: "fk_book_subjects_book"
    add_foreign_key :book_subjects, :subjects, column: [ :tenant_id, :subject_id ], primary_key: [ :tenant_id, :id ], name: "fk_book_subjects_subject"

    create_table :book_category_assignments, id: :uuid do |t|
      t.uuid :tenant_id, null: false
      t.uuid :book_id, null: false
      t.uuid :book_category_id, null: false
      t.timestamps
    end
    add_index :book_category_assignments, [ :book_id, :book_category_id ], unique: true, name: "index_book_category_assignments_on_book_and_category"
    add_foreign_key :book_category_assignments, :tenants
    add_foreign_key :book_category_assignments, :books, column: [ :tenant_id, :book_id ], primary_key: [ :tenant_id, :id ], name: "fk_book_category_assignments_book"
    add_foreign_key :book_category_assignments, :book_categories, column: [ :tenant_id, :book_category_id ], primary_key: [ :tenant_id, :id ], name: "fk_book_category_assignments_category"

    create_table :book_genres, id: :uuid do |t|
      t.uuid :tenant_id, null: false
      t.uuid :book_id, null: false
      t.uuid :genre_id, null: false
      t.timestamps
    end
    add_index :book_genres, [ :book_id, :genre_id ], unique: true, name: "index_book_genres_on_book_id_and_genre_id"
    add_foreign_key :book_genres, :tenants
    add_foreign_key :book_genres, :books, column: [ :tenant_id, :book_id ], primary_key: [ :tenant_id, :id ], name: "fk_book_genres_book"
    add_foreign_key :book_genres, :genres, column: [ :tenant_id, :genre_id ], primary_key: [ :tenant_id, :id ], name: "fk_book_genres_genre"
  end

  def create_media
    create_table :book_media, id: :uuid do |t|
      t.uuid :tenant_id, null: false
      t.uuid :book_edition_id, null: false
      t.string :media_type, null: false, limit: 50
      t.string :storage_key, null: false, limit: 500
      t.string :original_filename, limit: 255
      t.string :mime_type, null: false, limit: 100
      t.bigint :file_size, null: false
      t.integer :width
      t.integer :height
      t.string :variant, limit: 30
      t.string :alt_text, limit: 500
      t.boolean :is_primary, null: false, default: false
      t.bigint :uploaded_by, null: false
      t.timestamps
    end
    add_foreign_key :book_media, :tenants
    add_foreign_key :book_media, :book_editions, column: [ :tenant_id, :book_edition_id ], primary_key: [ :tenant_id, :id ], name: "fk_book_media_edition"
    add_foreign_key :book_media, :users, column: :uploaded_by
    add_index :book_media, [ :book_edition_id, :media_type ], unique: true, where: "is_primary", name: "index_book_media_one_primary_per_type"
    add_check_constraint :book_media, "media_type IN ('cover', 'back_cover', 'sample')", name: "book_media_type_check"
    add_check_constraint :book_media, "file_size > 0 AND file_size <= 5242880", name: "book_media_file_size_check"
  end

  def create_metadata
    create_table :book_metadata, id: :uuid do |t|
      t.uuid :tenant_id, null: false
      t.uuid :book_id, null: false
      t.string :metadata_schema, null: false, limit: 100
      t.string :metadata_key, null: false, limit: 150
      t.jsonb :metadata_value, null: false, default: {}
      t.timestamps
    end
    add_index :book_metadata, [ :book_id, :metadata_schema, :metadata_key ], unique: true, name: "index_book_metadata_on_book_schema_and_key"
    add_foreign_key :book_metadata, :tenants
    add_foreign_key :book_metadata, :books, column: [ :tenant_id, :book_id ], primary_key: [ :tenant_id, :id ], name: "fk_book_metadata_book"
  end

  def create_audit_logs
    create_table :book_audit_logs, id: :uuid do |t|
      t.uuid :tenant_id, null: false
      t.uuid :book_id, null: false
      t.uuid :book_edition_id
      t.bigint :actor_id
      t.string :action, null: false, limit: 50
      t.jsonb :old_values, null: false, default: {}
      t.jsonb :new_values, null: false, default: {}
      t.text :reason
      t.uuid :correlation_id
      t.datetime :created_at, null: false
    end
    add_index :book_audit_logs, [ :book_id, :created_at ], name: "index_book_audit_logs_on_book_id_and_created_at"
    add_foreign_key :book_audit_logs, :tenants
    add_foreign_key :book_audit_logs, :books, column: [ :tenant_id, :book_id ], primary_key: [ :tenant_id, :id ], on_delete: :cascade, name: "fk_book_audit_logs_book"
    add_foreign_key :book_audit_logs, :book_editions, column: [ :tenant_id, :book_edition_id ], primary_key: [ :tenant_id, :id ], name: "fk_book_audit_logs_edition"
    add_foreign_key :book_audit_logs, :users, column: :actor_id
  end

  def create_outbox
    create_table :catalogue_outbox_events, id: :uuid do |t|
      t.uuid :tenant_id, null: false
      t.string :event_name, null: false, limit: 100
      t.jsonb :payload, null: false, default: {}
      t.datetime :published_at
      t.datetime :created_at, null: false
    end
    add_index :catalogue_outbox_events, :created_at, where: "published_at IS NULL", name: "index_catalogue_outbox_events_unpublished"
    add_foreign_key :catalogue_outbox_events, :tenants
  end

  def create_search_indexes
    execute "CREATE INDEX index_books_on_title_trgm ON books USING gin (title gin_trgm_ops)"
    execute "CREATE INDEX index_authors_on_display_name_trgm ON authors USING gin (display_name gin_trgm_ops)"
    execute "CREATE INDEX index_publishers_on_name_trgm ON publishers USING gin (name gin_trgm_ops)"
    execute "CREATE INDEX index_book_identifiers_on_value_trgm ON book_identifiers USING gin (identifier_value gin_trgm_ops)"
  end
end
