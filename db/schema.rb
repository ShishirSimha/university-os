# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_11_18_140000) do
  connection.execute("CREATE SCHEMA IF NOT EXISTS library")

  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pg_trgm"
  enable_extension "pgcrypto"

  create_table "author_aliases", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "tenant_id", null: false
    t.uuid "author_id", null: false
    t.string "name", limit: 300, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index "author_id, lower((name)::text)", name: "index_author_aliases_on_author_id_and_lower_name", unique: true
    t.index ["tenant_id", "id"], name: "index_author_aliases_on_tenant_id_and_id", unique: true
  end

  create_table "authors", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "first_name", limit: 150
    t.string "last_name", limit: 150
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "tenant_id", null: false
    t.string "middle_name", limit: 150
    t.string "display_name", limit: 300, null: false
    t.text "biography"
    t.string "orcid", limit: 50
    t.string "nationality_code", limit: 10
    t.string "status", limit: 30, default: "active", null: false
    t.index ["display_name"], name: "index_authors_on_display_name_trgm", opclass: :gin_trgm_ops, using: :gin
    t.index ["tenant_id", "display_name"], name: "index_authors_on_tenant_id_and_display_name"
    t.index ["tenant_id", "id"], name: "index_authors_on_tenant_id_and_id", unique: true
    t.check_constraint "status::text = ANY (ARRAY['active'::character varying, 'archived'::character varying]::text[])", name: "authors_status_check"
  end

  create_table "book_audit_logs", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "tenant_id", null: false
    t.uuid "book_id", null: false
    t.uuid "book_edition_id"
    t.bigint "actor_id"
    t.string "action", limit: 50, null: false
    t.jsonb "old_values", default: {}, null: false
    t.jsonb "new_values", default: {}, null: false
    t.text "reason"
    t.uuid "correlation_id"
    t.datetime "created_at", null: false
    t.index ["book_id", "created_at"], name: "index_book_audit_logs_on_book_id_and_created_at"
  end

  create_table "book_authors", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "tenant_id", null: false
    t.uuid "book_id", null: false
    t.uuid "author_id", null: false
    t.string "contributor_role", limit: 50, null: false
    t.integer "sequence_number", default: 1, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["book_id", "author_id", "contributor_role"], name: "index_book_authors_on_book_author_and_role", unique: true
    t.index ["book_id", "sequence_number"], name: "index_book_authors_on_book_id_and_sequence_number"
    t.check_constraint "contributor_role::text = ANY (ARRAY['author'::character varying, 'co_author'::character varying, 'editor'::character varying, 'translator'::character varying, 'illustrator'::character varying, 'compiler'::character varying, 'contributor'::character varying]::text[])", name: "book_authors_role_check"
    t.check_constraint "sequence_number > 0", name: "book_authors_sequence_check"
  end

  create_table "book_categories", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "tenant_id", null: false
    t.uuid "parent_id"
    t.string "name", limit: 150, null: false
    t.string "code", limit: 100, null: false
    t.text "description"
    t.string "status", limit: 30, default: "active", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["tenant_id", "code"], name: "index_book_categories_on_tenant_id_and_code", unique: true
    t.index ["tenant_id", "id"], name: "index_book_categories_on_tenant_id_and_id", unique: true
    t.check_constraint "parent_id IS NULL OR parent_id <> id", name: "book_categories_parent_check"
    t.check_constraint "status::text = ANY (ARRAY['active'::character varying, 'archived'::character varying]::text[])", name: "book_categories_status_check"
  end

  create_table "book_category_assignments", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "tenant_id", null: false
    t.uuid "book_id", null: false
    t.uuid "book_category_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["book_id", "book_category_id"], name: "index_book_category_assignments_on_book_and_category", unique: true
  end

  create_table "book_edition_contributors", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "tenant_id", null: false
    t.uuid "book_edition_id", null: false
    t.uuid "author_id", null: false
    t.string "contributor_role", limit: 50, null: false
    t.integer "sequence_number", default: 1, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["book_edition_id", "author_id", "contributor_role"], name: "index_edition_contributors_on_edition_author_and_role", unique: true
    t.check_constraint "contributor_role::text = ANY (ARRAY['author'::character varying, 'co_author'::character varying, 'editor'::character varying, 'translator'::character varying, 'illustrator'::character varying, 'compiler'::character varying, 'contributor'::character varying]::text[])", name: "edition_contributors_role_check"
    t.check_constraint "sequence_number > 0", name: "edition_contributors_sequence_check"
  end

  create_table "book_editions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "tenant_id", null: false
    t.uuid "book_id", null: false
    t.uuid "publisher_id"
    t.string "edition_number", limit: 50
    t.string "edition_title", limit: 500
    t.date "publication_date"
    t.integer "publication_year"
    t.uuid "language_id"
    t.uuid "format_id"
    t.integer "page_count"
    t.integer "width_mm"
    t.integer "height_mm"
    t.integer "depth_mm"
    t.integer "weight_grams"
    t.string "volume_number", limit: 50
    t.string "series_name", limit: 255
    t.text "edition_description"
    t.string "status", limit: 30, default: "active", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["tenant_id", "book_id"], name: "index_book_editions_on_tenant_id_and_book_id"
    t.index ["tenant_id", "id"], name: "index_book_editions_on_tenant_id_and_id", unique: true
    t.check_constraint "page_count IS NULL OR page_count > 0", name: "book_editions_page_count_check"
    t.check_constraint "publication_year IS NULL OR publication_year >= 1 AND publication_year <= 3000", name: "book_editions_year_check"
    t.check_constraint "status::text = ANY (ARRAY['active'::character varying, 'archived'::character varying]::text[])", name: "book_editions_status_check"
  end

  create_table "book_formats", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "code", limit: 50, null: false
    t.string "name", limit: 100, null: false
    t.text "description"
    t.boolean "is_active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_book_formats_on_code", unique: true
  end

  create_table "book_genres", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "tenant_id", null: false
    t.uuid "book_id", null: false
    t.uuid "genre_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["book_id", "genre_id"], name: "index_book_genres_on_book_id_and_genre_id", unique: true
  end

  create_table "book_identifiers", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "tenant_id", null: false
    t.uuid "book_edition_id", null: false
    t.string "identifier_type", limit: 30, null: false
    t.string "identifier_value", limit: 100, null: false
    t.boolean "is_primary", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["book_edition_id"], name: "index_book_identifiers_one_primary", unique: true, where: "is_primary"
    t.index ["identifier_value"], name: "index_book_identifiers_on_value_trgm", opclass: :gin_trgm_ops, using: :gin
    t.index ["tenant_id", "identifier_type", "identifier_value"], name: "index_book_identifiers_on_tenant_type_and_value", unique: true
    t.index ["tenant_id", "identifier_value"], name: "index_book_identifiers_on_tenant_id_and_value"
    t.check_constraint "identifier_type::text = ANY (ARRAY['ISBN_10'::character varying, 'ISBN_13'::character varying, 'DOI'::character varying, 'OCLC'::character varying, 'LCCN'::character varying, 'OTHER'::character varying]::text[])", name: "book_identifiers_type_check"
  end

  create_table "book_media", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "tenant_id", null: false
    t.uuid "book_edition_id", null: false
    t.string "media_type", limit: 50, null: false
    t.string "storage_key", limit: 500, null: false
    t.string "original_filename", limit: 255
    t.string "mime_type", limit: 100, null: false
    t.bigint "file_size", null: false
    t.integer "width"
    t.integer "height"
    t.string "variant", limit: 30
    t.string "alt_text", limit: 500
    t.boolean "is_primary", default: false, null: false
    t.bigint "uploaded_by", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["book_edition_id", "media_type"], name: "index_book_media_one_primary_per_type", unique: true, where: "is_primary"
    t.check_constraint "file_size > 0 AND file_size <= 5242880", name: "book_media_file_size_check"
    t.check_constraint "media_type::text = ANY (ARRAY['cover'::character varying, 'back_cover'::character varying, 'sample'::character varying]::text[])", name: "book_media_type_check"
  end

  create_table "book_metadata", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "tenant_id", null: false
    t.uuid "book_id", null: false
    t.string "metadata_schema", limit: 100, null: false
    t.string "metadata_key", limit: 150, null: false
    t.jsonb "metadata_value", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["book_id", "metadata_schema", "metadata_key"], name: "index_book_metadata_on_book_schema_and_key", unique: true
  end

  create_table "book_subjects", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "tenant_id", null: false
    t.uuid "book_id", null: false
    t.uuid "subject_id", null: false
    t.boolean "is_primary", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["book_id", "subject_id"], name: "index_book_subjects_on_book_id_and_subject_id", unique: true
    t.index ["book_id"], name: "index_book_subjects_one_primary", unique: true, where: "is_primary"
  end

  create_table "books", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "tenant_id", null: false
    t.string "title", limit: 500, null: false
    t.string "subtitle", limit: 500
    t.text "description"
    t.uuid "original_language_id"
    t.uuid "primary_category_id"
    t.string "work_type", limit: 50, default: "book", null: false
    t.string "status", limit: 30, default: "draft", null: false
    t.string "catalogue_number", limit: 100
    t.bigint "created_by", null: false
    t.bigint "updated_by", null: false
    t.datetime "published_at"
    t.datetime "archived_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["tenant_id", "catalogue_number"], name: "index_books_on_tenant_id_and_catalogue_number", unique: true, where: "(catalogue_number IS NOT NULL)"
    t.index ["tenant_id", "created_at"], name: "index_books_on_tenant_id_and_created_at"
    t.index ["tenant_id", "id"], name: "index_books_on_tenant_id_and_id", unique: true
    t.index ["tenant_id", "status"], name: "index_books_on_tenant_id_and_status"
    t.index ["tenant_id", "title"], name: "index_books_on_tenant_id_and_title"
    t.index ["title"], name: "index_books_on_title_trgm", opclass: :gin_trgm_ops, using: :gin
    t.check_constraint "status::text = ANY (ARRAY['draft'::character varying, 'under_review'::character varying, 'published'::character varying, 'archived'::character varying, 'rejected'::character varying, 'withdrawn'::character varying]::text[])", name: "books_status_check"
    t.check_constraint "work_type::text = ANY (ARRAY['book'::character varying, 'textbook'::character varying, 'reference_work'::character varying, 'thesis'::character varying, 'other'::character varying]::text[])", name: "books_work_type_check"
  end

  create_table "catalogue_outbox_events", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "tenant_id", null: false
    t.string "event_name", limit: 100, null: false
    t.jsonb "payload", default: {}, null: false
    t.datetime "published_at"
    t.datetime "created_at", null: false
    t.index ["created_at"], name: "index_catalogue_outbox_events_unpublished", where: "(published_at IS NULL)"
  end

  create_table "genres", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "tenant_id", null: false
    t.string "name", limit: 150, null: false
    t.string "code", limit: 100, null: false
    t.string "status", limit: 30, default: "active", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["tenant_id", "code"], name: "index_genres_on_tenant_id_and_code", unique: true
    t.index ["tenant_id", "id"], name: "index_genres_on_tenant_id_and_id", unique: true
    t.check_constraint "status::text = ANY (ARRAY['active'::character varying, 'archived'::character varying]::text[])", name: "genres_status_check"
  end

  create_table "languages", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "code", limit: 10, null: false
    t.string "name", limit: 100, null: false
    t.string "native_name", limit: 100
    t.boolean "is_active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_languages_on_code", unique: true
  end

  create_table "publishers", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "tenant_id", null: false
    t.string "name", limit: 255, null: false
    t.text "description"
    t.string "website", limit: 500
    t.string "country_code", limit: 10
    t.string "email", limit: 255
    t.string "status", limit: 30, default: "active", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_publishers_on_name_trgm", opclass: :gin_trgm_ops, using: :gin
    t.index ["tenant_id", "id"], name: "index_publishers_on_tenant_id_and_id", unique: true
    t.index ["tenant_id", "name"], name: "index_publishers_on_tenant_id_and_name"
    t.check_constraint "status::text = ANY (ARRAY['active'::character varying, 'archived'::character varying]::text[])", name: "publishers_status_check"
  end

  create_table "revoked_tokens", force: :cascade do |t|
    t.string "jti", null: false
    t.datetime "expires_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["jti"], name: "index_revoked_tokens_on_jti", unique: true
  end

  create_table "subjects", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "tenant_id", null: false
    t.uuid "parent_id"
    t.string "name", limit: 255, null: false
    t.string "code", limit: 100, null: false
    t.string "classification_scheme", limit: 50, default: "LOCAL", null: false
    t.string "external_identifier", limit: 150
    t.text "description"
    t.string "status", limit: 30, default: "active", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["tenant_id", "classification_scheme", "code"], name: "index_subjects_on_tenant_scheme_and_code", unique: true
    t.index ["tenant_id", "id"], name: "index_subjects_on_tenant_id_and_id", unique: true
    t.check_constraint "classification_scheme::text = ANY (ARRAY['DDC'::character varying, 'UDC'::character varying, 'LCC'::character varying, 'LOCAL'::character varying]::text[])", name: "subjects_scheme_check"
    t.check_constraint "parent_id IS NULL OR parent_id <> id", name: "subjects_parent_check"
    t.check_constraint "status::text = ANY (ARRAY['active'::character varying, 'archived'::character varying]::text[])", name: "subjects_status_check"
  end

  create_table "tenants", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "name", limit: 255, null: false
    t.string "code", limit: 50, null: false
    t.string "status", limit: 30, default: "active", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_tenants_on_code", unique: true
    t.check_constraint "status::text = ANY (ARRAY['active'::character varying, 'suspended'::character varying]::text[])", name: "tenants_status_check"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", null: false
    t.string "password_digest", null: false
    t.string "name", null: false
    t.string "account_type", null: false
    t.string "country", null: false
    t.string "country_code", null: false
    t.string "state", null: false
    t.string "address", null: false
    t.string "phone_number", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "tenant_id", null: false
    t.index ["tenant_id", "email"], name: "index_users_on_tenant_id_and_email", unique: true
    t.check_constraint "account_type::text = ANY (ARRAY['user'::character varying, 'admin'::character varying]::text[])", name: "users_account_type_check"
  end

  add_foreign_key "author_aliases", "authors", column: ["tenant_id", "author_id"], primary_key: ["tenant_id", "id"], name: "fk_author_aliases_author"
  add_foreign_key "author_aliases", "tenants"
  add_foreign_key "authors", "tenants"
  add_foreign_key "book_audit_logs", "book_editions", column: ["tenant_id", "book_edition_id"], primary_key: ["tenant_id", "id"], name: "fk_book_audit_logs_edition"
  add_foreign_key "book_audit_logs", "books", column: ["tenant_id", "book_id"], primary_key: ["tenant_id", "id"], name: "fk_book_audit_logs_book", on_delete: :cascade
  add_foreign_key "book_audit_logs", "tenants"
  add_foreign_key "book_audit_logs", "users", column: "actor_id"
  add_foreign_key "book_authors", "authors", column: ["tenant_id", "author_id"], primary_key: ["tenant_id", "id"], name: "fk_book_authors_author"
  add_foreign_key "book_authors", "books", column: ["tenant_id", "book_id"], primary_key: ["tenant_id", "id"], name: "fk_book_authors_book"
  add_foreign_key "book_authors", "tenants"
  add_foreign_key "book_categories", "book_categories", column: ["tenant_id", "parent_id"], primary_key: ["tenant_id", "id"], name: "fk_book_categories_parent"
  add_foreign_key "book_categories", "tenants"
  add_foreign_key "book_category_assignments", "book_categories", column: ["tenant_id", "book_category_id"], primary_key: ["tenant_id", "id"], name: "fk_book_category_assignments_category"
  add_foreign_key "book_category_assignments", "books", column: ["tenant_id", "book_id"], primary_key: ["tenant_id", "id"], name: "fk_book_category_assignments_book"
  add_foreign_key "book_category_assignments", "tenants"
  add_foreign_key "book_edition_contributors", "authors", column: ["tenant_id", "author_id"], primary_key: ["tenant_id", "id"], name: "fk_edition_contributors_author"
  add_foreign_key "book_edition_contributors", "book_editions", column: ["tenant_id", "book_edition_id"], primary_key: ["tenant_id", "id"], name: "fk_edition_contributors_edition"
  add_foreign_key "book_edition_contributors", "tenants"
  add_foreign_key "book_editions", "book_formats", column: "format_id"
  add_foreign_key "book_editions", "books", column: ["tenant_id", "book_id"], primary_key: ["tenant_id", "id"], name: "fk_book_editions_book"
  add_foreign_key "book_editions", "languages"
  add_foreign_key "book_editions", "publishers", column: ["tenant_id", "publisher_id"], primary_key: ["tenant_id", "id"], name: "fk_book_editions_publisher"
  add_foreign_key "book_editions", "tenants"
  add_foreign_key "book_genres", "books", column: ["tenant_id", "book_id"], primary_key: ["tenant_id", "id"], name: "fk_book_genres_book"
  add_foreign_key "book_genres", "genres", column: ["tenant_id", "genre_id"], primary_key: ["tenant_id", "id"], name: "fk_book_genres_genre"
  add_foreign_key "book_genres", "tenants"
  add_foreign_key "book_identifiers", "book_editions", column: ["tenant_id", "book_edition_id"], primary_key: ["tenant_id", "id"], name: "fk_book_identifiers_edition"
  add_foreign_key "book_identifiers", "tenants"
  add_foreign_key "book_media", "book_editions", column: ["tenant_id", "book_edition_id"], primary_key: ["tenant_id", "id"], name: "fk_book_media_edition"
  add_foreign_key "book_media", "tenants"
  add_foreign_key "book_media", "users", column: "uploaded_by"
  add_foreign_key "book_metadata", "books", column: ["tenant_id", "book_id"], primary_key: ["tenant_id", "id"], name: "fk_book_metadata_book"
  add_foreign_key "book_metadata", "tenants"
  add_foreign_key "book_subjects", "books", column: ["tenant_id", "book_id"], primary_key: ["tenant_id", "id"], name: "fk_book_subjects_book"
  add_foreign_key "book_subjects", "subjects", column: ["tenant_id", "subject_id"], primary_key: ["tenant_id", "id"], name: "fk_book_subjects_subject"
  add_foreign_key "book_subjects", "tenants"
  add_foreign_key "books", "book_categories", column: ["tenant_id", "primary_category_id"], primary_key: ["tenant_id", "id"], name: "fk_books_primary_category"
  add_foreign_key "books", "languages", column: "original_language_id"
  add_foreign_key "books", "tenants"
  add_foreign_key "books", "users", column: "created_by"
  add_foreign_key "books", "users", column: "updated_by"
  add_foreign_key "catalogue_outbox_events", "tenants"
  add_foreign_key "genres", "tenants"
  add_foreign_key "publishers", "tenants"
  add_foreign_key "subjects", "subjects", column: ["tenant_id", "parent_id"], primary_key: ["tenant_id", "id"], name: "fk_subjects_parent"
  add_foreign_key "subjects", "tenants"
  add_foreign_key "users", "tenants"
end
