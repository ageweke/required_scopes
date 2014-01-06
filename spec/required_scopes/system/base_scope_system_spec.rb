require 'required_scopes'
require 'required_scopes/helpers/database_helper'
require 'required_scopes/helpers/system_helpers'

describe "RequiredScopes base scope operations" do
  include RequiredScopes::Helpers::SystemHelpers

  before :each do
    @dh = RequiredScopes::Helpers::DatabaseHelper.new
    @dh.setup_activerecord!

    create_standard_system_spec_tables!
    create_standard_system_spec_models!
    create_standard_system_spec_instances!

    ::User.class_eval do
      base_scope_required!

      base_scope :red, lambda { where(:favorite_color => 'red') }
      base_scope :green, lambda { where(:favorite_color => 'green') }

      scope :salty, lambda { where(:favorite_taste => 'salty') }

      class << self
        def blue
          base_scope_satisfied.where(:favorite_color => 'blue')
        end
      end
    end
  end

  after :each do
    drop_standard_system_spec_tables!
  end

  it "should require the base scope" do
    e = nil

    begin
      ::User.all.to_a
    rescue RequiredScopes::Errors::BaseScopeNotSatisfiedError => bsnse
      e = bsnse
    end

    e.should be
    e.class.should == RequiredScopes::Errors::BaseScopeNotSatisfiedError
    e.model_class.should == ::User

    e.current_relation.should be
    e.current_relation.kind_of?(::ActiveRecord::Relation).should be
    e.triggering_method.should == :exec_queries

    e.required_categories.should == [ :base ]
    e.satisfied_categories.should == [ ]
    e.missing_categories.should == [ :base ]

    e.message.should match(/base scope/i)
  end

  it "should work if a base scope is used" do
    ::User.red.to_a
  end

  it "should work if a class method satisfying the base scope is used" do
    ::User.blue.to_a
  end

  it "should work if you manually tell it that the base scope is satisfied" do
    ::User.base_scope_satisfied.to_a
  end
end
