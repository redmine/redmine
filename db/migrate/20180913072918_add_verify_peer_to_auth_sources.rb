class AddVerifyPeerToAuthSources < ActiveRecord::Migration[5.2]
  def change
    change_table :auth_sources do |t|
      t.boolean :verify_peer, default: true, null: false
    end
  end
end
