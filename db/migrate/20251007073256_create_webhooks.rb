class CreateWebhooks < ActiveRecord::Migration[8.0]
  def change
    create_table :webhooks do |t|
      t.string :url, null: false, limit: 2000
      t.string :secret
      t.text :events
      t.integer :user_id, null: false, index: true
      t.boolean :active, null: false, default: false, index: true
      t.timestamps
    end

    create_table :projects_webhooks do |t|
      t.integer :project_id, null: false, index: true
      t.integer :webhook_id, null: false, index: true
    end
  end
end
