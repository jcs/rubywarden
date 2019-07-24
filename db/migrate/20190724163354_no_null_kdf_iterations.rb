class NoNullKdfIterations < ActiveRecord::Migration[5.1]
  def change
    User.all.each do |u|
      if !u.kdf_iterations
        u.kdf_iterations = Bitwarden::KDF::DEFAULT_ITERATIONS[User::DEFAULT_KDF_TYPE]
      end
      if !u.kdf_type
        u.kdf_type = User::DEFAULT_KDF_TYPE
      end
      u.save!
    end

    change_column :users, :kdf_iterations, :integer, :null => false,
      :default => Bitwarden::KDF::DEFAULT_ITERATIONS[User::DEFAULT_KDF_TYPE]
  end
end
