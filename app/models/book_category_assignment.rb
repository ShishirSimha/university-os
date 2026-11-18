class BookCategoryAssignment < ApplicationRecord
  include TenantOwned

  belongs_to :book
  belongs_to :book_category

  validates :book_category_id, uniqueness: { scope: :book_id }
  validate :category_is_assignable

  before_validation :copy_tenant

  private

  def copy_tenant
    self.tenant_id = book.tenant_id if book
  end

  def category_is_assignable
    return if book_category.blank? || book.blank?
    errors.add(:book_category, "must belong to the same institution") if book_category.tenant_id != book.tenant_id
    errors.add(:book_category, "is archived") if book_category.archived?
  end
end
