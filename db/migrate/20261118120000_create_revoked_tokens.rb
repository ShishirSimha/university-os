class CreateRevokedTokens < ActiveRecord::Migration[8.1]
  def up
    execute "CREATE SCHEMA IF NOT EXISTS library"
    execute "SET search_path TO library"

    create_table :revoked_tokens do |t|
      t.string :jti, null: false
      t.datetime :expires_at, null: false

      t.timestamps
    end

    add_index :revoked_tokens, :jti, unique: true
  end

  def down
    execute "SET search_path TO library"
    drop_table :revoked_tokens
  end
end
