class EquivalentDomain < DBModel
  belongs_to :user, foreign_key: :user_uuid, inverse_of: :folders
  serialize :domains, JSON

  def update_domains domains:
    self.domains = domains
  end

end
