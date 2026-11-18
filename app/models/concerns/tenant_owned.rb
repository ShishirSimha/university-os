module TenantOwned
  extend ActiveSupport::Concern

  included do
    include UuidPrimaryKey
    belongs_to :tenant
  end
end
