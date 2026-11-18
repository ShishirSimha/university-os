module ContributorAssignment
  extend ActiveSupport::Concern

  ROLES = %w[author co_author editor translator illustrator compiler contributor].freeze

  included do
    include TenantOwned
    belongs_to :author

    validates :contributor_role, inclusion: { in: ROLES, message: "must be #{ROLES.join(', ')}" }
    validates :sequence_number, numericality: { only_integer: true, greater_than: 0 }
    validate :author_can_be_assigned
    before_validation :normalize_contributor
  end

  def summary_json
    {
      id: id,
      authorId: author_id,
      displayName: author&.display_name,
      role: contributor_role,
      sequence: sequence_number
    }
  end

  private

  def normalize_contributor
    self.contributor_role = contributor_role.to_s.strip.downcase.gsub(/[\s-]+/, "_").presence
    self.sequence_number = sequence_number.presence || 1
    self.tenant_id = tenant_parent.tenant_id if tenant_parent
  end

  def author_can_be_assigned
    return if author.blank? || tenant_parent.blank?
    errors.add(:author, "must belong to the same institution") if author.tenant_id != tenant_parent.tenant_id
    return unless new_record? || author_id_changed?
    errors.add(:author, "is archived") if author.archived?
  end
end
