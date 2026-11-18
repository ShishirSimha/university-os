class BookAuthor < ApplicationRecord
  include ContributorAssignment

  belongs_to :book

  validates :author_id, uniqueness: { scope: [ :book_id, :contributor_role ], message: "already has this role on the work" }

  private

  def tenant_parent
    book
  end
end
