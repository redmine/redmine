class CreateDoorkeeperTables < ActiveRecord::Migration[7.2]
  def change
    create_table :oauth_applications do |t|
      t.string  :name,         null: false
      t.string  :uid,          null: false
      t.string  :secret,       null: false
      t.text    :redirect_uri, null: false
      t.text    :scopes,       null: false
      t.boolean :confidential, null: false, default: true
      t.timestamps             null: false
    end

    add_index :oauth_applications, :uid, unique: true

    create_table :oauth_access_grants do |t|
      t.integer  :resource_owner_id, null: false
      t.references :application,     null: false
      t.string   :token,             null: false
      t.integer  :expires_in,        null: false
      t.text     :redirect_uri,      null: false
      t.datetime :created_at,        null: false
      t.datetime :revoked_at
      t.text     :scopes
    end

    add_index :oauth_access_grants, :token, unique: true
    add_foreign_key(
      :oauth_access_grants,
      :oauth_applications,
      column: :application_id
    )
    add_foreign_key(
      :oauth_access_grants,
      :users,
      column: :resource_owner_id
    )

    create_table :oauth_access_tokens do |t|
      t.integer  :resource_owner_id
      t.references :application

      t.string   :token,                  null: false

      t.string   :refresh_token
      t.integer  :expires_in
      t.datetime :revoked_at
      t.datetime :created_at,             null: false
      t.text     :scopes

      t.string   :previous_refresh_token, null: false, default: ""
    end

    add_index :oauth_access_tokens, :token, unique: true
    add_index :oauth_access_tokens, :resource_owner_id
    add_index :oauth_access_tokens, :refresh_token, unique: true

    add_foreign_key(
      :oauth_access_tokens,
      :oauth_applications,
      column: :application_id
    )
    add_foreign_key(
      :oauth_access_tokens,
      :users,
      column: :resource_owner_id
    )
  end
end
