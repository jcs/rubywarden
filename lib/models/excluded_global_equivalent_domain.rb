class ExcludedGlobalEquivalentDomain < DBModel
  belongs_to :global_equivalent_domain, inverse_of: :excluded_global_equivalent_domains
  belongs_to :user, foreign_key: :user_uuid
end