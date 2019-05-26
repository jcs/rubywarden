class PasswordHistory < ActiveRecord::Migration[5.1]
  def change
    add_column :ciphers, :passwordhistory, :binary
  end
end
