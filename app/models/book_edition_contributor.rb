class BookEditionContributor < ApplicationRecord
  include ContributorAssignment

  belongs_to :book_edition

  validates :author_id, uniqueness: { scope: [ :book_edition_id, :contributor_role ], message: "already has this role on the edition" }

  private

  def tenant_parent
    book_edition
  end
end
