class CreateTenants < ActiveRecord::Migration[8.1]
  def up
    execute "CREATE SCHEMA IF NOT EXISTS library"
    execute "SET search_path TO library"
    enable_extension "pgcrypto" unless extension_enabled?("pgcrypto")

    create_table :tenants, id: :uuid do |t|
      t.string :name, null: false, limit: 255
      t.string :code, null: false, limit: 50
      t.string :status, null: false, default: "active", limit: 30

      t.timestamps
    end

    add_index :tenants, :code, unique: true
    add_check_constraint :tenants, "status IN ('active', 'suspended')", name: "tenants_status_check"

    add_column :users, :tenant_id, :uuid

    execute <<~SQL.squish
      INSERT INTO tenants (id, name, code, status, created_at, updated_at)
      SELECT gen_random_uuid(), 'Legacy Institution', 'LEGACY', 'active', NOW(), NOW()
      WHERE EXISTS (SELECT 1 FROM users)
        AND NOT EXISTS (SELECT 1 FROM tenants WHERE code = 'LEGACY')
    SQL

    execute <<~SQL.squish
      UPDATE users
      SET tenant_id = (SELECT id FROM tenants WHERE code = 'LEGACY')
      WHERE tenant_id IS NULL
    SQL

    change_column_null :users, :tenant_id, false
    add_foreign_key :users, :tenants
    remove_index :users, :email, name: "index_users_on_email"
    add_index :users, [ :tenant_id, :email ], unique: true, name: "index_users_on_tenant_id_and_email"
  end

  def down
    execute "SET search_path TO library"
    remove_index :users, name: "index_users_on_tenant_id_and_email"
    add_index :users, :email, unique: true, name: "index_users_on_email"
    remove_foreign_key :users, :tenants
    remove_column :users, :tenant_id
    drop_table :tenants
  end
end
