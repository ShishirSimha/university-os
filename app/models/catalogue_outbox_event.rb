class CatalogueOutboxEvent < ApplicationRecord
  include TenantOwned

  validates :event_name, presence: true, length: { maximum: 100 }
  validates :payload, presence: true
end
