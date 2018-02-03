require "spec_helper.rb"

@users = nil
@geds = nil

describe "global equivalent domains" do
  before do
    GlobalEquivalentDomain.all.each &:destroy
    User.all.each &:destroy
    ExcludedGlobalEquivalentDomain.all.each &:destroy
    GlobalEquivalentDomain.new.save
    GlobalEquivalentDomain.new.save
    User.new.save
    User.new.save
    @users = User.all
    @geds = GlobalEquivalentDomain.all
  end

  it "allows excluding a domain for a user" do
    ged = @geds.first
    user = @users.first
    ged.exclude_for_user user: user
    eged = ExcludedGlobalEquivalentDomain.all.first
    eged.user_uuid.must_equal user.uuid
  end

  it "retrieves active global domains for user" do
    active = GlobalEquivalentDomain.active_for_user user: @users.first
    active.size.must_equal @geds.size
    assert active.none? {|a| a.excluded }
    ged = @geds.first
    ged.exclude_for_user user: @users.last
    active = GlobalEquivalentDomain.active_for_user user: @users.last
    active.size.must_equal 2
    assert active.any? {|a| a.excluded }
  end

end