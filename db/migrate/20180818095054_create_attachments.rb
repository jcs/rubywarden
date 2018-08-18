class CreateAttachments < ActiveRecord::Migration[5.1]
  def change
    remove_column :ciphers, :attachments
    create_table :attachments, id: :string, primary_key: :uuid do |t|
      t.string :cipher_uuid
      t.string :url
      t.string :filename
      t.integer :size
      t.binary :file
      t.timestamps
    end
    add_foreign_key :attachments, :ciphers, { column: :cipher_uuid, primary_key: :uuid }
    add_index(:attachments, :cipher_uuid)
  end
end
