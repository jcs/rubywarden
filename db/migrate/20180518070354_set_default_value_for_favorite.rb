class SetDefaultValueForFavorite < ActiveRecord::Migration[5.1]
  class Cipher < ActiveRecord::Base; end
  def change
    change_column_default :ciphers, :favorite, false
    Cipher.where(favorite: nil).update_all favorite: false
  end
end
