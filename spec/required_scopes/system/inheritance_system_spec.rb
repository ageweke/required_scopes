require 'required_scopes'
require 'required_scopes/helpers/database_helper'
require 'required_scopes/helpers/system_helpers'

describe "RequiredScopes and inheritance" do
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

  it "should combine multiple #must_scope_by declarations" do
    ::User.class_eval do
      must_scope_by :color
      must_scope_by :taste

      scope :red, lambda { where(:favorite_color => 'red') }, :category => :color
      scope :salty, lambda { where(:favorite_taste => 'salty') }, :category => :taste
    end

    should_raise_missing_scopes(:exec_queries, [ :color, :taste ], [ :taste ]) { ::User.salty.to_a }
  end

  it "should inherit #must_scope_by in child classes" do
    ::User.class_eval do
      must_scope_by :color
      scope :red, lambda { where(:favorite_color => 'red') }, :category => :color
    end

    class ::UserSub1 < ::User
      self.table_name = ::User.table_name

      must_scope_by :taste
      scope :salty, lambda { where(:favorite_taste => 'salty') }, :category => :taste
    end

    should_raise_missing_scopes(:exec_queries, [ :color, :taste ], [ :taste ], :model_class => ::UserSub1) { ::UserSub1.salty.to_a }
  end

  it "should allow ignoring a required scope in a subclass" do
    ::User.class_eval do
      must_scope_by :color
      scope :red, lambda { where(:favorite_color => 'red') }, :category => :color
    end

    class ::UserSub2 < ::User
      self.table_name = ::User.table_name

      must_scope_by :taste
      scope :salty, lambda { where(:favorite_taste => 'salty') }, :category => :taste

      ignore_parent_scope_requirement :color
    end

    ::UserSub2.salty.to_a.should be
    should_raise_missing_scopes(:exec_queries, [ :taste ], [ ], :model_class => ::UserSub2) { ::UserSub2.all.to_a }
  end
end
