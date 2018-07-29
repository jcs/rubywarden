class SetDefaultValueForFavorite < ActiveRecord::Migration[5.1]
  class Cipher < ActiveRecord::Base; end
  def change
    change_column_default :ciphers, :favorite, false
    change_column_null(:ciphers, :favorite, false, false)
  end
end
