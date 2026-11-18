class BookGenre < ApplicationRecord
  include TenantOwned

  belongs_to :book
  belongs_to :genre

  validates :genre_id, uniqueness: { scope: :book_id }
  validate :genre_is_assignable

  before_validation :copy_tenant

  private

  def copy_tenant
    self.tenant_id = book.tenant_id if book
  end

  def genre_is_assignable
    return if genre.blank? || book.blank?
    errors.add(:genre, "must belong to the same institution") if genre.tenant_id != book.tenant_id
    errors.add(:genre, "is archived") if genre.archived?
  end
end
