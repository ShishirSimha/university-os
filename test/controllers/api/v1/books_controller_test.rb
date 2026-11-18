require "test_helper"

class Api::V1::BooksControllerTest < ActionDispatch::IntegrationTest
  setup do
    @institution = create_institution
    @admin = create_auth_user(tenant: @institution, email: "admin@abc.test", account_type: "admin", name: "Ada Admin")
    @student = create_auth_user(tenant: @institution, email: "student@abc.test", name: "Sam Student")
    @other = create_institution(name: "XYZ University", code: "XYZ")
    @other_admin = create_auth_user(tenant: @other, email: "admin@xyz.test", account_type: "admin", name: "Xavier Admin")
  end

  test "creates a draft work with editions and a normalized isbn" do
    author = create_author(firstName: "Robert", middleName: "C.", lastName: "Martin")
    publisher = create_publisher("Prentice Hall")

    assert_difference -> { CatalogueOutboxEvent.where(event_name: "catalogue.book.created").count }, 1 do
      assert_difference -> { CatalogueOutboxEvent.where(event_name: "catalogue.edition.created").count }, 2 do
        post "/api/v1/books", params: {
          title: "Clean Code",
          subtitle: "A Handbook of Agile Software Craftsmanship",
          description: "A handbook of software craftsmanship",
          status: "published",
          tenantId: @other.id,
          originalLanguageCode: "en",
          catalogueNumber: "CC-001",
          authors: [ { authorId: author["id"], role: "Author", sequence: 1 } ],
          editions: [
            {
              editionNumber: "1st Edition",
              publicationYear: 2008,
              formatCode: "PAPERBACK",
              languageCode: "en",
              publisherId: publisher["id"],
              identifiers: [ { type: "ISBN_13", value: "978-0-13-235088-4", primary: true } ]
            },
            {
              editionNumber: "2nd Edition",
              identifiers: [ { type: "ISBN_13", value: "9780132350891", primary: false } ]
            }
          ]
        }, headers: auth_headers(@admin), as: :json
      end
    end

    assert_response :created
    assert_equal 201, json["status"]
    assert_equal "Book created successfully", json["message"]
    assert_equal "draft", json.dig("data", "status")
    assert_nil json.dig("data", "publishedAt")
    assert_equal "Clean Code", json.dig("data", "title")
    assert_equal 2, json.dig("data", "editions").length
    assert_equal "9780132350884", json.dig("data", "editions", 0, "identifiers", 0, "value")
    assert_equal true, json.dig("data", "editions", 0, "identifiers", 0, "primary")
    assert_equal "Robert C. Martin", json.dig("data", "authors", 0, "displayName")
    assert_nil json.dig("data", "inventorySummary", 0, "totalCopies")
    assert_nil json.dig("data", "inventorySummary", 0, "available")
    assert_nil json.dig("data", "inventorySummary", 0, "onLoan")

    book = Book.find(json.dig("data", "id"))
    assert_equal @institution.id, book.tenant_id
    assert_equal "draft", book.status
  end

  test "rejects a book without a title" do
    post "/api/v1/books", params: { description: "Missing title" }, headers: auth_headers(@admin), as: :json

    assert_response :bad_request
    assert_equal 400, json["status"]
    assert_match(/Title/, json["message"])
  end

  test "rejects a duplicate catalogue number" do
    post "/api/v1/books", params: { title: "Clean Code", catalogueNumber: "CC-001" }, headers: auth_headers(@admin), as: :json
    assert_response :created

    post "/api/v1/books", params: { title: "Another Title", catalogueNumber: "CC-001" }, headers: auth_headers(@admin), as: :json

    assert_response :conflict
    assert_equal 409, json["status"]
    assert_match(/[Cc]atalogue number/, json["message"])
  end

  test "warns about a duplicate title without blocking it" do
    post "/api/v1/books", params: { title: "Clean Code", catalogueNumber: "CC-001" }, headers: auth_headers(@admin), as: :json
    original_id = json.dig("data", "id")

    post "/api/v1/books", params: { title: "clean code", catalogueNumber: "CC-002" }, headers: auth_headers(@admin), as: :json

    assert_response :created
    assert_equal original_id, json.dig("data", "possibleDuplicates", 0, "id")
  end

  test "associates multiple authors in display order" do
    martin = create_author(firstName: "Robert", lastName: "Martin")
    beck = create_author(firstName: "Kent", lastName: "Beck")

    post "/api/v1/books", params: {
      title: "Clean Code",
      authors: [
        { authorId: beck["id"], role: "co-author", sequence: 2 },
        { authorId: martin["id"], role: "Author", sequence: 1 }
      ]
    }, headers: auth_headers(@admin), as: :json

    assert_response :created
    names = json.dig("data", "authors").map { |author| author["displayName"] }
    assert_equal [ "Robert Martin", "Kent Beck" ], names
  end

  test "rejects an invalid isbn and stores no work" do
    post "/api/v1/books", params: {
      title: "Broken Isbn",
      editions: [ { editionNumber: "1", identifiers: [ { type: "ISBN_13", value: "9780132350885" } ] } ]
    }, headers: auth_headers(@admin), as: :json

    assert_response :bad_request
    assert_match(/ISBN_13/, json["message"])
    assert_not Book.exists?(title: "Broken Isbn", tenant_id: @institution.id)
  end

  test "rejects a duplicate isbn in the same institution and allows it in another" do
    create_book_with_isbn("9780132350884")

    post "/api/v1/books", params: {
      title: "Duplicate Isbn",
      editions: [ { identifiers: [ { type: "ISBN_13", value: "978-0-13-235088-4" } ] } ]
    }, headers: auth_headers(@admin), as: :json

    assert_response :conflict
    assert_equal 409, json["status"]

    post "/api/v1/books", params: {
      title: "Duplicate Isbn",
      editions: [ { identifiers: [ { type: "ISBN_13", value: "9780132350884" } ] } ]
    }, headers: auth_headers(@other_admin), as: :json

    assert_response :created
  end

  test "updates metadata and writes an audit record" do
    book_id = create_book_with_isbn("9780132350884")

    patch "/api/v1/books/#{book_id}", params: { title: "Clean Code Revised", reason: "Corrected title" }, headers: auth_headers(@admin), as: :json

    assert_response :ok
    assert_equal "Book updated successfully", json["message"]
    assert_equal "Clean Code Revised", json.dig("data", "title")
    audit = BookAuditLog.where(book_id: book_id, action: "UPDATE").order(:created_at).last
    assert_equal "Clean Code Revised", audit.new_values["title"]
    assert_equal "Corrected title", audit.reason
    assert_equal @admin.id, audit.actor_id
  end

  test "publishes a draft and records the publication event" do
    book_id = create_book_with_isbn("9780132350884")

    assert_difference -> { CatalogueOutboxEvent.where(event_name: "catalogue.book.published").count }, 1 do
      post "/api/v1/books/#{book_id}/publish", headers: auth_headers(@admin), as: :json
    end

    assert_response :ok
    assert_equal "Book published successfully", json["message"]
    assert_equal "published", json.dig("data", "status")
    assert BookAuditLog.exists?(book_id: book_id, action: "PUBLISH")
  end

  test "archives a published book without inventing circulation state" do
    book_id = publish_book

    post "/api/v1/books/#{book_id}/archive", headers: auth_headers(@admin), as: :json

    assert_response :ok
    assert_equal "Book archived successfully", json["message"]
    assert_equal "archived", json.dig("data", "status")
    assert_equal [], json.dig("data", "circulationWarnings")
    assert_nil json.dig("data", "inventorySummary", 0, "totalCopies")

    get "/api/v1/books", headers: auth_headers(@student), as: :json
    assert_response :ok
    assert_not_includes json.dig("data", "books").map { |book| book["id"] }, book_id
  end

  test "deletes an unused draft and rejects deletion of a published book or a draft with editions" do
    post "/api/v1/books", params: { title: "Disposable Draft" }, headers: auth_headers(@admin), as: :json
    draft_id = json.dig("data", "id")
    delete "/api/v1/books/#{draft_id}", headers: auth_headers(@admin), as: :json
    assert_response :ok
    assert_equal "Draft deleted successfully", json["message"]
    assert_not Book.exists?(draft_id)

    published_id = publish_book
    delete "/api/v1/books/#{published_id}", headers: auth_headers(@admin), as: :json
    assert_response :conflict
    assert_match(/Only unused drafts/, json["message"])
    assert Book.exists?(published_id)

    post "/api/v1/books", params: {
      title: "Draft With Edition",
      editions: [ { editionNumber: "1" } ]
    }, headers: auth_headers(@admin), as: :json
    edition_book_id = json.dig("data", "id")
    delete "/api/v1/books/#{edition_book_id}", headers: auth_headers(@admin), as: :json
    assert_response :conflict
    assert Book.exists?(edition_book_id)
  end

  test "deletes an edition of a draft and keeps the audit history" do
    post "/api/v1/books", params: {
      title: "Draft With Edition",
      editions: [ { editionNumber: "1" } ]
    }, headers: auth_headers(@admin), as: :json
    book_id = json.dig("data", "id")
    edition_id = json.dig("data", "editions", 0, "id")

    delete "/api/v1/editions/#{edition_id}", headers: auth_headers(@admin), as: :json

    assert_response :ok
    assert_equal "Edition deleted successfully", json["message"]
    assert_not BookEdition.exists?(edition_id)
    assert BookAuditLog.where(book_id: book_id).where.not(action: nil).exists?
    assert_not BookAuditLog.where(book_edition_id: edition_id).exists?
  end

  test "hides another institution's book and a draft from a student" do
    book_id = create_book_with_isbn("9780132350884")

    get "/api/v1/books/#{book_id}", headers: auth_headers(@other_admin), as: :json
    assert_response :not_found
    assert_equal "Record not found", json["message"]
    assert_not_includes response.body, "Clean Code"

    patch "/api/v1/books/#{book_id}", params: { title: "Taken Over" }, headers: auth_headers(@other_admin), as: :json
    assert_response :not_found
    assert_equal "Clean Code", Book.find(book_id).title

    get "/api/v1/books/#{book_id}", headers: auth_headers(@student), as: :json
    assert_response :not_found

    post "/api/v1/books/#{book_id}/publish", headers: auth_headers(@student), as: :json
    assert_response :forbidden
    assert_equal 403, json["status"]
    assert_equal "draft", Book.find(book_id).status
  end

  test "rejects invalid cover metadata" do
    book_id = create_book_with_isbn("9780132350884")
    edition_id = Book.find(book_id).editions.pick(:id)

    post "/api/v1/books/#{book_id}/media", params: {
      editionId: edition_id,
      mediaType: "cover",
      storageKey: "covers/clean-code.svg",
      mimeType: "image/svg+xml",
      fileSize: 1200,
      altText: "Front cover"
    }, headers: auth_headers(@admin), as: :json
    assert_response :bad_request

    post "/api/v1/books/#{book_id}/media", params: {
      editionId: edition_id,
      mediaType: "cover",
      storageKey: "covers/clean-code.jpg",
      mimeType: "image/jpeg",
      fileSize: 5.megabytes + 1,
      altText: "Front cover"
    }, headers: auth_headers(@admin), as: :json
    assert_response :bad_request

    post "/api/v1/books/#{book_id}/media", params: {
      editionId: edition_id,
      mediaType: "cover",
      storageKey: "covers/clean-code.jpg",
      mimeType: "image/jpeg",
      fileSize: 1200,
      altText: "Front cover",
      primary: true
    }, headers: auth_headers(@admin), as: :json
    assert_response :created
    assert_equal "covers/clean-code.jpg", json.dig("data", "storageKey")
    media = BookMedia.find(json.dig("data", "id"))
    assert_equal "image/jpeg", media.mime_type
    assert_equal 1200, media.file_size
  end

  test "searches published books by author and isbn" do
    author = create_author(firstName: "Robert", middleName: "C.", lastName: "Martin")
    post "/api/v1/books", params: {
      title: "Clean Code",
      authors: [ { authorId: author["id"], role: "author" } ],
      editions: [ { identifiers: [ { type: "ISBN_13", value: "9780132350884" } ] } ]
    }, headers: auth_headers(@admin), as: :json
    book_id = json.dig("data", "id")
    post "/api/v1/books/#{book_id}/publish", headers: auth_headers(@admin), as: :json
    assert_response :ok

    get "/api/v1/books", params: { author: "Martin" }, headers: auth_headers(@student), as: :json
    assert_response :ok
    assert_includes json.dig("data", "books").map { |book| book["id"] }, book_id

    get "/api/v1/books", params: { isbn: "978-0-13-235088-4" }, headers: auth_headers(@student), as: :json
    assert_response :ok
    assert_equal [ book_id ], json.dig("data", "books").map { |book| book["id"] }
  end

  test "reflects an author change and keeps the association after archival" do
    author = create_author(firstName: "Robert", middleName: "C.", lastName: "Martin")
    post "/api/v1/books", params: {
      title: "Clean Code",
      authors: [ { authorId: author["id"], role: "author" } ]
    }, headers: auth_headers(@admin), as: :json
    book_id = json.dig("data", "id")

    patch "/api/v1/authors/#{author["id"]}", params: { displayName: "Robert Martin" }, headers: auth_headers(@admin), as: :json
    assert_response :ok

    get "/api/v1/books/#{book_id}", headers: auth_headers(@admin), as: :json
    assert_equal "Robert Martin", json.dig("data", "authors", 0, "displayName")
    assert BookAuditLog.where(book_id: book_id, action: "UPDATE").where("new_values::text LIKE ?", "%Robert Martin%").exists?

    post "/api/v1/authors/#{author["id"]}/archive", headers: auth_headers(@admin), as: :json
    assert_response :ok
    assert_equal "Author archived successfully", json["message"]

    get "/api/v1/books/#{book_id}", headers: auth_headers(@admin), as: :json
    assert_equal author["id"], json.dig("data", "authors", 0, "authorId")
    assert BookAuthor.exists?(book_id: book_id, author_id: author["id"])
  end

  test "assigns categories subjects genres and extra metadata" do
    post "/api/v1/categories", params: { name: "Computer Science", code: "CS" }, headers: auth_headers(@admin), as: :json
    category_id = json.dig("data", "id")
    post "/api/v1/subjects", params: { name: "Software Engineering", code: "SE", classificationScheme: "LOCAL" }, headers: auth_headers(@admin), as: :json
    subject_id = json.dig("data", "id")
    post "/api/v1/genres", params: { name: "Technical", code: "TECH" }, headers: auth_headers(@admin), as: :json
    genre_id = json.dig("data", "id")
    post "/api/v1/books", params: { title: "Clean Code" }, headers: auth_headers(@admin), as: :json
    book_id = json.dig("data", "id")

    patch "/api/v1/books/#{book_id}", params: {
      categoryIds: [ category_id ],
      subjectIds: [ subject_id ],
      genreIds: [ genre_id ],
      metadata: [ { schema: "local", key: "audience", value: { level: "undergraduate" } } ]
    }, headers: auth_headers(@admin), as: :json

    assert_response :ok
    assert_equal "Computer Science", json.dig("data", "categories", 0, "name")
    assert_equal "Software Engineering", json.dig("data", "subjects", 0, "name")
    assert_equal "Technical", json.dig("data", "genres", 0, "name")
    assert_equal "undergraduate", json.dig("data", "metadata", 0, "value", "level")
  end

  test "filters the published catalogue by language year format and publisher" do
    publisher = create_publisher("Prentice Hall")
    post "/api/v1/books", params: {
      title: "Clean Code",
      catalogueNumber: "CC-FILTER",
      originalLanguageCode: "en",
      editions: [ {
        editionNumber: "1st Edition",
        publicationYear: 2008,
        formatCode: "PAPERBACK",
        languageCode: "en",
        publisherId: publisher["id"]
      } ]
    }, headers: auth_headers(@admin), as: :json
    book_id = json.dig("data", "id")
    post "/api/v1/books/#{book_id}/publish", headers: auth_headers(@admin), as: :json
    assert_response :ok

    post "/api/v1/books", params: {
      title: "Other Work",
      catalogueNumber: "CC-OTHER",
      originalLanguageCode: "hi",
      editions: [ { editionNumber: "1", publicationYear: 1999, formatCode: "HARDCOVER", languageCode: "hi" } ]
    }, headers: auth_headers(@admin), as: :json
    other_id = json.dig("data", "id")
    post "/api/v1/books/#{other_id}/publish", headers: auth_headers(@admin), as: :json

    get "/api/v1/books", params: { language: "en", publicationYear: 2008, format: "PAPERBACK", publisher: "Prentice", edition: "1st" }, headers: auth_headers(@student), as: :json

    assert_response :ok
    assert_equal [ book_id ], json.dig("data", "books").map { |book| book["id"] }

    get "/api/v1/books", params: { publicationYear: 1999 }, headers: auth_headers(@student), as: :json
    assert_equal [ other_id ], json.dig("data", "books").map { |book| book["id"] }
  end

  test "adds an edition identifier and an edition contributor" do
    author = create_author(firstName: "Robert", lastName: "Martin")
    post "/api/v1/books", params: { title: "Clean Code", catalogueNumber: "CC-ADD" }, headers: auth_headers(@admin), as: :json
    book_id = json.dig("data", "id")
    post "/api/v1/books/#{book_id}/editions", params: { editionNumber: "1st Edition", languageCode: "en" }, headers: auth_headers(@admin), as: :json
    assert_response :created
    edition_id = json.dig("data", "id")

    post "/api/v1/editions/#{edition_id}/identifiers", params: { type: "ISBN_10", value: "0-13-235088-2", primary: true }, headers: auth_headers(@admin), as: :json
    assert_response :created
    assert_equal "0132350882", json.dig("data", "value")

    post "/api/v1/editions/#{edition_id}/contributors", params: { authorId: author["id"], role: "Translator" }, headers: auth_headers(@admin), as: :json
    assert_response :created
    assert_equal "translator", json.dig("data", "role")
  end

  test "supports the review lifecycle" do
    post "/api/v1/books", params: { title: "Reviewed Work" }, headers: auth_headers(@admin), as: :json
    book_id = json.dig("data", "id")

    post "/api/v1/books/#{book_id}/submit", headers: auth_headers(@admin), as: :json
    assert_response :ok
    assert_equal "Book submitted for review", json["message"]
    assert_equal "under_review", json.dig("data", "status")

    post "/api/v1/books/#{book_id}/reject", headers: auth_headers(@admin), as: :json
    assert_equal "rejected", json.dig("data", "status")

    post "/api/v1/books/#{book_id}/publish", headers: auth_headers(@admin), as: :json
    assert_response :conflict
  end

  private

  def json
    response.parsed_body
  end

  def create_author(attrs)
    post "/api/v1/authors", params: attrs, headers: auth_headers(@admin), as: :json
    assert_response :created
    response.parsed_body["data"]
  end

  def create_publisher(name)
    post "/api/v1/publishers", params: { name: name, website: "https://example.test" }, headers: auth_headers(@admin), as: :json
    assert_response :created
    response.parsed_body["data"]
  end

  def create_book_with_isbn(isbn)
    post "/api/v1/books", params: {
      title: "Clean Code",
      catalogueNumber: "CC-#{isbn[-4..]}",
      editions: [ { editionNumber: "1st Edition", identifiers: [ { type: "ISBN_13", value: isbn, primary: true } ] } ]
    }, headers: auth_headers(@admin), as: :json
    assert_response :created
    response.parsed_body.dig("data", "id")
  end

  def publish_book
    book_id = create_book_with_isbn("9780132350884")
    post "/api/v1/books/#{book_id}/publish", headers: auth_headers(@admin), as: :json
    assert_response :ok
    book_id
  end
end
