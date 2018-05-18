class CreateDevices < ActiveRecord::Migration[5.1]
  def change
    create_table :devices, id: :string, primary_key: :uuid do |t|
      t.string :user_uuid
      t.string :name
      t.integer :type
      t.string :push_token
      t.string :access_token
      t.string :refresh_token
      t.datetime :token_expires_at
      t.timestamps
      t.index :push_token, unique: true
      t.index :access_token, unique: true
      t.index :refresh_token, unique: true
    end
    add_foreign_key :devices, :users, { column: :user_uuid, primary_key: :uuid }
    add_index(:devices, :user_uuid)

  end
end
