class UserKdfIterations < ActiveRecord::Migration[5.1]
  def change
    add_column :users, :kdf_iterations, :integer

    User.all.each do |u|
      u.kdf_iterations = User::DEFAULT_KDF_ITERATIONS
      u.save!
    end
  end
end
