class Current < ActiveSupport::CurrentAttributes
  attribute :user, :tenant, :correlation_id
end
