class CreateFolders < ActiveRecord::Migration[5.1]
  def change
    create_table :folders, id: :string, primary_key: :uuid do |t|
      t.string :user_uuid
      t.binary :name
      t.timestamps
    end
    add_foreign_key :folders, :users, { column: :user_uuid, primary_key: :uuid }
    add_index(:folders, :user_uuid)

  end
end
