require 'required_scopes'
require 'required_scopes/helpers/database_helper'
require 'required_scopes/helpers/system_helpers'

describe "RequiredScopes static-scope operations" do
  include RequiredScopes::Helpers::SystemHelpers

  before :each do
    @dh = RequiredScopes::Helpers::DatabaseHelper.new
    @dh.setup_activerecord!

    create_standard_system_spec_tables!
    create_standard_system_spec_models!
    create_standard_system_spec_instances!
  end

  after :each do
    drop_standard_system_spec_tables!
  end

  it "should support static scopes" do
    ::User.class_eval do
      must_scope_by :color

      scope :red, where(:favorite_color => 'red'), :satisfies => :color
    end

    lambda { ::User.all.to_a }.should raise_error(RequiredScopes::Errors::RequiredScopeCategoriesNotSatisfiedError)
    ::User.red.to_a.length.should >= 1
  end
end
