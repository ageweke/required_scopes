require 'required_scopes'
require 'required_scopes/helpers/database_helper'
require 'required_scopes/helpers/system_helpers'

describe "RequiredScopes basic operations" do
  include RequiredScopes::Helpers::SystemHelpers

  before :each do
    @dh = RequiredScopes::Helpers::DatabaseHelper.new
    @dh.setup_activerecord!

    create_standard_system_spec_tables!
    create_standard_system_spec_models!
    create_standard_system_spec_instances!

    define_color_and_taste_scopes!
  end

  after :each do
    drop_standard_system_spec_tables!
  end

  describe "queries" do
    it "should raise if no categories are applied" do
      should_raise_missing_scopes(:exec_queries, [ :color, :taste ], [ ]) { ::User.all.to_a }
    end

    it "should raise if only one category is applied" do
      should_raise_missing_scopes(:exec_queries, [ :color, :taste ], [ :color ]) { ::User.red.to_a }
    end

    it "should not raise if both categories are individually applied" do
      ::User.red.salty.to_a.should == [ @red_salty ]
    end

    it "should not raise if both categories are satisfied by a single scope" do
      ::User.red_and_salty.to_a.should == [ @red_salty ]
    end

    it "should allow further qualifying the scopes, and in the middle" do
      ::User.where("name LIKE 'red%'").red.where("name LIKE '%salty'").salty.where("name LIKE '%d-s%'").to_a.should == [ @red_salty ]
      ::User.where("name LIKE 'green%'").red.salty.to_a.should == [ ]
      ::User.red.where("name LIKE '%sweet'").salty.to_a.should == [ ]
      ::User.red.salty.where("name LIKE '%sweet'").to_a.should == [ ]
    end

    it "should automatically have a scope that includes all of each category" do
      ::User.red.ignoring_taste.to_a.sort.should == [ @red_salty, @red_sweet ].sort
      ::User.ignoring_color.sweet.to_a.sort.should == [ @red_sweet, @green_sweet, @blue_sweet ].sort
    end

    it "should still require scopes even if #unscoped is used" do
      should_raise_missing_scopes(:exec_queries, [ :color, :taste ], [ ]) { ::User.unscoped.to_a }
    end

    it "should still require scopes even if #unscoped is used in a block form" do
      should_raise_missing_scopes(:exec_queries, [ :color, :taste ], [ ]) { ::User.unscoped { ::User.all.to_a } }
    end

    it "should allow manually saying that categories are satisfied" do
      ::User.red.scope_category_satisfied(:taste).to_a.sort.should == [ @red_salty, @red_sweet ].to_a
      ::User.scope_category_satisfied(:color).sweet.to_a.sort.should == [ @red_sweet, @green_sweet, @blue_sweet ].to_a
      ::User.scope_categories_satisfied(:color, :taste).to_a.sort.should ==
        [ @red_sweet, @green_sweet, @blue_sweet, @red_salty, @green_salty, @blue_salty ].to_a.sort
      ::User.scope_categories_satisfied(:color, :taste).sweet.to_a.sort.should ==
        [ @red_sweet, @green_sweet, @blue_sweet ].to_a.sort
    end

    it "should allow manually saying that categories are satisfied, in a block" do
      ran_block = false
      ::User.scope_category_satisfied(:taste) do
        ::User.red.to_a.sort.should == [ @red_salty, @red_sweet].to_a
        ran_block = true
      end
      ran_block.should be

      ran_block = false
      ::User.scope_category_satisfied(:taste) do
        should_raise_missing_scopes(:exec_queries, [ :color, :taste ], [ :taste ]) { ::User.all.to_a }
        ran_block = true
      end
      ran_block.should be

      ran_block = false
      ::User.scope_category_satisfied(:taste) do
        ::User.red.to_a.sort.should == [ @red_salty, @red_sweet ].sort
        ran_block = true
      end
      ran_block.should be

      ran_block = false
      ::User.all_scope_categories_satisfied do
        ::User.all.to_a.sort.should == [ @red_salty, @red_sweet, @green_salty, @green_sweet, @blue_salty, @blue_sweet ].sort
        ran_block = true
      end
      ran_block.should be
    end

    it "should allow saying that categories are satisfied in a class method, in any position" do
      ::User.class_eval do
        class << self
          def red_and_green
            scope_category_satisfied(:color).where(:favorite_color => %w{red green})
          end

          def green_and_blue
            where(:favorite_color => %w{green blue}).scope_category_satisfied(:color)
          end

          def just_blue
            where(:favorite_color => %w{red blue}).scope_category_satisfied(:color).where(:favorite_color => %w{blue green})
          end
        end
      end

      ::User.red_and_green.salty.to_a.sort.should == [ @red_salty, @green_salty ].sort
      ::User.green_and_blue.salty.to_a.sort.should == [ @green_salty, @blue_salty ].sort
      ::User.just_blue.salty.to_a.sort.should == [ @blue_salty ].sort
    end
  end
end
