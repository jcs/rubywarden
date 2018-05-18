class CreateUsers < ActiveRecord::Migration[5.1]
  def change
    create_table :users, id: :string, primary_key: :uuid do |t|
      t.text :email
      t.boolean :email_verified, default: true
      t.boolean :premium, default: true
      t.text :name
      t.text :password_hash
      t.text :password_hint
      t.text :key
      t.binary :private_key
      t.binary :public_key
      t.string :totp_secret
      t.string :security_stamp
      t.string :culture
      t.timestamps
      t.index :email, unique: true
    end
  end
end
