class UserKdfIterations < ActiveRecord::Migration[5.1]
  def change
    add_column :users, :kdf_iterations, :integer

    User.all.each do |u|
      u.kdf_iterations = Bitwarden::KDF::DEFAULT_ITERATIONS[User::DEFAULT_KDF_TYPE]
      u.save!
    end
  end
end
