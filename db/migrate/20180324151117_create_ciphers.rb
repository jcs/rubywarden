class CreateCiphers < ActiveRecord::Migration[5.1]
  def change
    create_table :ciphers, id: :string, primary_key: :uuid do |t|
      t.string :user_uuid
      t.string :folder_uuid
      t.string :organization_uuid
      t.integer :type
      t.binary :data
      t.boolean :favorite
      t.binary :attachments
      t.binary :name
      t.binary :notes
      t.binary :fields
      t.binary :login
      t.binary :card
      t.binary :identity
      t.binary :securenote
      t.timestamps
    end
    add_foreign_key :ciphers, :users, { column: :user_uuid, primary_key: :uuid }
    add_index(:ciphers, :user_uuid)
    add_foreign_key :ciphers, :folders, { column: :folder_uuid, primary_key: :uuid }
    add_index(:ciphers, :folder_uuid)

  end
end
