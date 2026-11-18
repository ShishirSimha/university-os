class BookAuditLog < ApplicationRecord
  include TenantOwned

  belongs_to :book
  belongs_to :book_edition, optional: true
  belongs_to :actor, class_name: "User", optional: true, inverse_of: false

  validates :action, presence: true, length: { maximum: 50 }

  def readonly?
    persisted?
  end

  def catalogue_json
    {
      id: id,
      bookId: book_id,
      bookEditionId: book_edition_id,
      actorId: actor_id,
      action: action,
      oldValues: old_values,
      newValues: new_values,
      reason: reason,
      correlationId: correlation_id,
      createdAt: created_at
    }
  end
end
