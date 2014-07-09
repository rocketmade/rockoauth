class RockoauthSchemaAddUniqueIndexes < ActiveRecord::Migration
  FIELDS = [:code, :refresh_token_hash]

  def self.up
    FIELDS.each do |field|
      remove_index :oauth2_authorizations, :name => "index_oauth2_client_id_and_#{field}"
      add_index :oauth2_authorizations, [:client_id, field], :unique => true, :name => "index_oauth2_client_id_#{field}"
    end
    remove_index :oauth2_authorizations, [:access_token_hash]
    add_index :oauth2_authorizations, [:access_token_hash], :unique => true

    remove_index :oauth2_clients, [:client_id]
    add_index :oauth2_clients, [:client_id], :unique => true

    add_index :oauth2_clients, [:name], :unique => true
  end

  def self.down
    FIELDS.each do |field|
      remove_index :oauth2_authorizations, [:client_id, field]
      add_index :oauth2_authorizations, [:client_id, field]
    end
    remove_index :oauth2_authorizations, [:access_token_hash]
    add_index :oauth2_authorizations, [:access_token_hash]

    remove_index :oauth2_clients, [:client_id]
    add_index :oauth2_clients, [:client_id]

    remove_index :oauth2_clients, [:name]
  end
end
