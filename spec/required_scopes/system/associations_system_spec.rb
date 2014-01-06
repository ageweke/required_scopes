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

      drop_table :rec_spec_user_preferences rescue nil
      create_table :rec_spec_user_preferences do |t|
        t.integer :user_id
        t.string :preference
      end

      drop_table :rec_spec_categories rescue nil
      create_table :rec_spec_categories do |t|
        t.string :name
      end

      drop_table :rec_spec_categories_users rescue nil
      create_table :rec_spec_categories_users, :id => false do |t|
        t.integer :user_id
        t.integer :category_id
      end
    end

    define_model_class(:User, :rec_spec_users) do
      must_scope_by :color
      belongs_to :group
      has_one :user_preference
      has_and_belongs_to_many :categories, :join_table => :rec_spec_categories_users

      scope :red, lambda { where(:favorite_color => :red) }, :satisfies => :color
    end

    define_model_class(:Group, :rec_spec_groups) do
      has_many :users
    end

    define_model_class(:UserPreference, :rec_spec_user_preferences) do
      belongs_to :user

      must_scope_by :prefcolor
    end

    define_model_class(:Category, :rec_spec_categories) do
      has_and_belongs_to_many :users, :join_table => :rec_spec_categories_users

      must_scope_by :catcolor
    end

    @group1 = ::Group.create!(:name => 'Group 1')
    @user1 = ::User.create!(:name => 'g1u1', :favorite_color => 'red', :group => @group1)
    @user2 = ::User.create!(:name => 'g1u2', :favorite_color => 'green', :group => @group1)

    @user1pref = ::UserPreference.create!(:user => @user1, :preference => 'u1p')
    @user2pref = ::UserPreference.create!(:user => @user2, :preference => 'u2p')

    @cat1 = ::Category.create!(:name => 'c1')
    @cat2 = ::Category.create!(:name => 'c2')

    @cat1.users << @user1
    @cat1.users << @user2
    @cat1.save!

    @cat2.users << @user1
    @cat2.users << @user2
    @cat2.save!
  end

  after :each do
    migrate do
      drop_table :rec_spec_groups rescue nil
      drop_table :rec_spec_users rescue nil
      drop_table :rec_spec_user_preferences rescue nil
      drop_table :rec_spec_categories rescue nil
      drop_table :rec_spec_categories_users rescue nil
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
    if ::RequiredScopes::ActiveRecord::VersionCompatibility.supports_references_method?
      Group.references(:users).find(@group1.id).users.map(&:id).sort.should == [ @user1, @user2 ].map(&:id).sort
    end
  end

  it "should not require a scope when accessed via has_one" do
    @user1.user_preference.should == @user1pref
  end

  it "should not require a scope when accessed via has_one, with eager loading" do
    User.includes(:user_preference).red.find(@user1.id).id.should == @user1pref.id
  end

  it "should not require a scope when accessed via belongs_to" do
    @user1pref.user.should == @user1
  end

  it "should not require a scope when accessed via has_one, with eager loading" do
    UserPreference.includes(:user).all_scope_categories_satisfied.find(@user1pref.id).id.should == @user1.id
  end

  it "should not require a scope when accessed via has_and_belongs_to_many" do
    @user1.categories.map(&:id).sort.should == [ @cat1, @cat2 ].map(&:id).sort
  end

  it "should not require a scope when accessed via has_and_belongs_to_many, with eager loading" do
    ::User.includes(:categories).all_scope_categories_satisfied.find(@user1).categories.map(&:id).should == [ @cat1, @cat2 ].map(&:id).sort
  end
end
