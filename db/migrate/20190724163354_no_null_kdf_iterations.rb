class NoNullKdfIterations < ActiveRecord::Migration[5.1]
  def change
    User.all.each do |u|
      # any old users without a kdf_iterations value probably have the old
      # value of 5000
      if !u.kdf_iterations
        u.kdf_iterations = 5000
        u.kdf_type = Bitwarden::KDF::PBKDF2
      end
      u.save!
    end

    # but going forward, any new users should get whatever defaults are set in
    # the future
    change_column :users, :kdf_iterations, :integer, :null => false,
      :default => Bitwarden::KDF::DEFAULT_ITERATIONS[User::DEFAULT_KDF_TYPE]
  end
end
