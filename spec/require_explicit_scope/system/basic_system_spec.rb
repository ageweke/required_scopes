require 'require_explicit_scope'
require 'require_explicit_scope/helpers/database_helper'
require 'require_explicit_scope/helpers/system_helpers'

describe "RequireExplicitScope basic operations" do
  include RequireExplicitScope::Helpers::SystemHelpers

  before :each do
    @dh = RequireExplicitScope::Helpers::DatabaseHelper.new
    @dh.setup_activerecord!

    create_standard_system_spec_tables!
    create_standard_system_spec_models!

    @user1 = ::User.new
    @user1.name = 'User 1'
    @user1.save!
  end

  after :each do
    drop_standard_system_spec_tables!
  end

  it "should allow requiring an explicit scope for direct queries" do
    lambda { ::User.where(:name => 'User 1') }.should raise_error
  end
end
