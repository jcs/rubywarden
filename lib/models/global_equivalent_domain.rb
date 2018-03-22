class GlobalEquivalentDomain < DBModel
  set_table_name "global_equivalent_domains"
  set_primary_key "id"

  attr_accessor :excluded
  def update_domains domains:
    self.domains = domains.to_json
  end

  def self.active_for_user user:
    excluded = ExcludedGlobalEquivalentDomain.find_all_by_user_uuid(user.uuid).map {|d| d.global_equivalent_domain_id }

    self.all.map do |d|
      d.excluded = excluded.include?(d.id)
      d
    end
  end

  def to_hash
    {
      "Type": self.id,
      "Domains": JSON.parse(self.domains),
      "Excluded": self.excluded
    }
  end

  def exclude_for_user user:
    ex = ExcludedGlobalEquivalentDomain.new
    ex.user_uuid = user.uuid
    ex.global_equivalent_domain_id = self.id
    ex.save
  end
end

class ExcludedGlobalEquivalentDomain < DBModel
  set_table_name "excluded_global_equivalent_domains"
end