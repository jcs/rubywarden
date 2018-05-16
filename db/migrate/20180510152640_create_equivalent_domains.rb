class CreateEquivalentDomains < ActiveRecord::Migration[5.1]
  def change
    create_table :global_equivalent_domains do |t|
      t.binary :domains
      t.timestamps
    end

    create_table :excluded_global_equivalent_domains do |t|
      t.references :global_equivalent_domain, foreign_key: true, index: { name: "eged_ged_fk" }
      t.string :user_uuid, null: false
      t.timestamps
    end

    create_table :equivalent_domains do |t|
      t.binary :domains, null: false
      t.string :user_uuid, null: false
      t.timestamps
    end
  end
end
