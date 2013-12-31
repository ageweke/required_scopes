require 'required_scopes'
require 'required_scopes/helpers/database_helper'
require 'required_scopes/helpers/system_helpers'

require 'pry'

describe "RequiredScopes basic operations" do
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

  def show(text)
    $stderr << "#{text} -> ..."
    $stderr.flush

    result = begin
      out = eval(text)
      out.inspect
      $stderr.puts "#{out.inspect}"
    rescue Exception => e
      $stderr.puts "EXCEPTION: (#{e.class.name}): #{e.message}"
    end

    $stderr.flush
  end

  def should_raise_missing_scopes(triggering_method, required, satisfied)
    e = result = nil

    begin
      result = yield
    rescue RequiredScopes::Errors::RequiredScopeCategoriesNotSatisfiedError => rscnse
      e = rscnse
    end

    raise "Expected a scopes-not-satisfied error, but got none" unless e

    expected_model_class = ::User

    e.class.should == RequiredScopes::Errors::RequiredScopeCategoriesNotSatisfiedError
    e.model_class.should == expected_model_class
    e.current_relation.should be
    e.current_relation.kind_of?(ActiveRecord::Relation).should be
    e.triggering_method.should == triggering_method
    e.required_categories.sort_by(&:to_s).should == required.sort_by(&:to_s)
    e.satisfied_categories.sort_by(&:to_s).should == satisfied.sort_by(&:to_s)

    expected_missing_categories = required - satisfied
    e.missing_categories.sort_by(&:to_s).should == expected_missing_categories.sort_by(&:to_s)

    e.message.should match(/#{expected_model_class.name}/)
    e.message.should match(/#{expected_missing_categories.sort_by(&:to_s).join(", ")}/)
  end

  context "with two required scope categories" do
    before :each do
      ::User.class_eval do
        must_scope_by :color, :taste

        scope :red, lambda { where(:favorite_color => 'red') }, :category => :color
        scope :green, lambda { where(:favorite_color => 'green') }, :category => :color

        scope :salty, lambda { where(:favorite_taste => 'salty') }, :category => :taste
        scope :sweet, lambda { where(:favorite_taste => 'sweet') }, :category => :taste

        scope :red_and_salty, lambda { where(:favorite_color => 'red', :favorite_taste => 'salty') }, :categories => [ :color, :taste ]
      end
    end

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
      ::User.red.all_tastes.to_a.sort.should == [ @red_salty, @red_sweet ].sort
      ::User.all_colors.sweet.to_a.sort.should == [ @red_sweet, @green_sweet, @blue_sweet ].sort
    end

    it "should skip all checks on #unscoped" do
      ::User.unscoped.to_a.sort.should == [ @red_salty, @red_sweet, @green_salty, @green_sweet, @blue_salty, @blue_sweet ].sort
    end

    it "should skip all checks on #unscoped, and persist through other scopes" do
      ::User.unscoped.red.to_a.sort.should == [ @red_salty, @red_sweet ].sort
    end

    it "should allow manually saying that categories are satisfied" do
      ::User.red.satisfying_category(:taste).to_a.sort.should == [ @red_salty, @red_sweet ].to_a
      ::User.satisfying_category(:color).sweet.to_a.sort.should == [ @red_sweet, @green_sweet, @blue_sweet ].to_a
      ::User.satisfying_categories(:color, :taste).to_a.sort.should ==
        [ @red_sweet, @green_sweet, @blue_sweet, @red_salty, @green_salty, @blue_salty ].to_a.sort
      ::User.satisfying_categories(:color, :taste).sweet.to_a.sort.should ==
        [ @red_sweet, @green_sweet, @blue_sweet ].to_a.sort
    end

    it "should allow saying that categories are satisfied in a class method, in any position" do
      ::User.class_eval do
        class << self
          def red_and_green
            satisfying_category(:color).where(:favorite_color => %w{red green})
          end

          def green_and_blue
            where(:favorite_color => %w{green blue}).satisfying_category(:color)
          end

          def just_blue
            where(:favorite_color => %w{red blue}).satisfying_category(:color).where(:favorite_color => %w{blue green})
          end
        end
      end

      ::User.red_and_green.salty.to_a.sort.should == [ @red_salty, @green_salty ].sort
      ::User.green_and_blue.salty.to_a.sort.should == [ @green_salty, @blue_salty ].sort
      ::User.just_blue.salty.to_a.sort.should == [ @blue_salty ].sort
    end
  end

    # ::User.class_eval do
    #   base_scope_required!

    #   base_scope :red, lambda { where(:favorite_color => 'red') }
    # end

end
