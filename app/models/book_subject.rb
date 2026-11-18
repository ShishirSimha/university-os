class BookSubject < ApplicationRecord
  include TenantOwned

  belongs_to :book
  belongs_to :subject

  validates :subject_id, uniqueness: { scope: :book_id }
  validate :subject_is_assignable

  before_validation :copy_tenant
  before_save :demote_other_primaries, if: :is_primary?

  def summary_json
    subject.reference_json.merge(assignmentId: id, primary: is_primary)
  end

  private

  def copy_tenant
    self.tenant_id = book.tenant_id if book
  end

  def subject_is_assignable
    return if subject.blank? || book.blank?
    errors.add(:subject, "must belong to the same institution") if subject.tenant_id != book.tenant_id
    errors.add(:subject, "is archived") if (new_record? || subject_id_changed?) && subject.archived?
  end

  def demote_other_primaries
    BookSubject.where(book_id: book_id, is_primary: true).where.not(id: id).update_all(is_primary: false)
  end
end
