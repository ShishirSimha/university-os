module Catalogue
  class AuditRecorder
    def self.record!(book:, action:, old_values: {}, new_values: {}, edition: nil, reason: nil)
      BookAuditLog.create!(
        tenant_id: book.tenant_id,
        book_id: book.id,
        book_edition_id: edition&.id,
        actor_id: Current.user&.id || book.updated_by || book.created_by,
        action: action,
        old_values: json_ready(old_values),
        new_values: json_ready(new_values),
        reason: reason.presence || book.audit_reason,
        correlation_id: Current.correlation_id
      )
    end

    def self.json_ready(values)
      JSON.parse(values.to_json)
    end
  end
end
