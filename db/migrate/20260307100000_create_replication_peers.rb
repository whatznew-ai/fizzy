class CreateReplicationPeers < ActiveRecord::Migration[8.2]
  def change
    create_table :replication_peers, id: :uuid do |t|
      t.string :name, null: false
      t.string :base_url, null: false
      t.string :auth_token, null: false
      t.integer :last_sent_db_version, default: 0, null: false
      t.datetime :last_pushed_at
      t.datetime :last_pulled_at
      t.string :state, default: "active", null: false
      t.integer :consecutive_failures, default: 0, null: false

      t.timestamps

      t.index :auth_token, unique: true
      t.index :state
    end
  end
end
