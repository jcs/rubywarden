class AddUserKdfType < ActiveRecord::Migration[5.1]
  def change
    add_column :users, :kdf_type, :integer, :default => 0, :null => false
  end
end
