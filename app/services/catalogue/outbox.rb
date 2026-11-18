module Catalogue
  class Outbox
    def self.record!(tenant_id:, event_name:, payload:)
      CatalogueOutboxEvent.create!(
        tenant_id: tenant_id,
        event_name: event_name,
        payload: payload,
        created_at: Time.current
      )
    end
  end
end
