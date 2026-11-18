module ActiveArchived
  extend ActiveSupport::Concern

  STATUSES = %w[active archived].freeze

  included do
    validates :status, inclusion: { in: STATUSES }
    before_validation :normalize_record_status
  end

  def active?
    status == "active"
  end

  def archived?
    status == "archived"
  end

  private

  def normalize_record_status
    self.status = status.to_s.strip.downcase.presence || "active"
  end
end
