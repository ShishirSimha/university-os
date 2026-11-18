module Catalogue
  class Duplicates
    def self.books(book)
      Book.where(tenant_id: book.tenant_id)
        .where("lower(books.title) = ?", book.title.to_s.downcase)
        .where.not(id: book.id)
        .order(:title)
        .limit(5)
        .map { |item| { id: item.id, title: item.title, catalogueNumber: item.catalogue_number } }
    end

    def self.authors(author)
      Author.where(tenant_id: author.tenant_id)
        .where("lower(authors.display_name) = ?", author.display_name.to_s.downcase)
        .where.not(id: author.id)
        .order(:display_name)
        .limit(5)
        .map { |item| { id: item.id, displayName: item.display_name } }
    end
  end
end
