require 'required_scopes'
require 'required_scopes/helpers/database_helper'
require 'required_scopes/helpers/system_helpers'

describe "RequiredScopes and associations" do
  include RequiredScopes::Helpers::SystemHelpers

  before :each do
    @dh = RequiredScopes::Helpers::DatabaseHelper.new
    @dh.setup_activerecord!

    migrate do
      drop_table :rec_spec_groups rescue nil
      create_table :rec_spec_groups do |t|
        t.string :name, :null => false
      end

      drop_table :rec_spec_users rescue nil
      create_table :rec_spec_users do |t|
        t.string :name, :null => false
        t.integer :group_id
        t.string :favorite_color
      end
    end

    define_model_class(:User, :rec_spec_users) do
      must_scope_by :color
      belongs_to :group

      scope :red, lambda { where(:favorite_color => :red) }, :satisfies => :color
    end

    define_model_class(:Group, :rec_spec_groups) do
      has_many :users
    end

    @group1 = ::Group.create!(:name => 'Group 1')
    @user1 = ::User.create!(:name => 'g1u1', :favorite_color => 'red', :group => @group1)
    @user2 = ::User.create!(:name => 'g1u2', :favorite_color => 'green', :group => @group1)
  end

  after :each do
    migrate do
      drop_table :rec_spec_groups rescue nil
      drop_table :rec_spec_users rescue nil
    end
  end

  it "should require a scope when accessed directly" do
    lambda { ::User.where(:group_id => @group1.id).to_a }.should raise_error(RequiredScopes::Errors::RequiredScopeCategoriesNotSatisfiedError)
  end

  it "should not require a scope when accessed via an association" do
    @group1.users.map(&:id).sort.should == [ @user1, @user2 ].map(&:id).sort
  end

  it "should not require a scope when accessed via an association, with eager loading" do
    Group.includes(:users).find(@group1.id).users.map(&:id).sort.should == [ @user1, @user2 ].map(&:id).sort
  end

  it "should not require a scope when accessed via #joins" do
    Group.joins(:users).find(@group1.id).users.map(&:id).sort.should == [ @user1, @user2 ].map(&:id).sort
  end

  it "should not require a scope when accessed via #eager_load" do
    Group.eager_load(:users).find(@group1.id).users.map(&:id).sort.should == [ @user1, @user2 ].map(&:id).sort
  end

  it "should not require a scope when accessed via #preload" do
    Group.preload(:users).find(@group1.id).users.map(&:id).sort.should == [ @user1, @user2 ].map(&:id).sort
  end

  it "should not require a scope when accessed via #references" do
    Group.references(:users).find(@group1.id).users.map(&:id).sort.should == [ @user1, @user2 ].map(&:id).sort
  end
end
