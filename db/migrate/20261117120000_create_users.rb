class CreateUsers < ActiveRecord::Migration[8.1]
  def up
    execute "CREATE SCHEMA IF NOT EXISTS library"
    execute "SET search_path TO library"

    create_table :users do |t|
      t.string :email, null: false
      t.string :password_digest, null: false
      t.string :name, null: false
      t.string :account_type, null: false
      t.string :country, null: false
      t.string :country_code, null: false
      t.string :state, null: false
      t.string :address, null: false
      t.string :phone_number, null: false

      t.timestamps
    end

    add_index :users, :email, unique: true
    add_check_constraint :users, "account_type IN ('user', 'admin')", name: "users_account_type_check"
  end

  def down
    execute "SET search_path TO library"
    drop_table :users
  end
end
