class GlobalEquivalentDomain < DBModel
  has_many :excluded_global_equivalent_domains, inverse_of: :global_equivalent_domain, dependent: :delete_all
  serialize :domains, JSON

  attr_accessor :excluded
  def update_domains domains:
    self.domains = domains
  end

  def self.active_for_user user:
    excluded = ExcludedGlobalEquivalentDomain.where(user_uuid: user.uuid).pluck(:global_equivalent_domain_id)

    self.all.map do |d|
      d.excluded = excluded.include?(d.id)
      d
    end
  end

  def to_hash
    {
      "Type": self.id,
      "Domains": self.domains,
      "Excluded": self.excluded
    }
  end

  def exclude_for_user user:
    ex = self.excluded_global_equivalent_domains.create user: user
    ex.persisted?
  end
end