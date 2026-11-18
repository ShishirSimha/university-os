module UuidPrimaryKey
  extend ActiveSupport::Concern

  included do
    self.implicit_order_column = "created_at"
  end
end
