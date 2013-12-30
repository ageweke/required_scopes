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

    @user1 = ::User.new
    @user1.name = 'User 1'
    @user1.save!
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

  it "should allow requiring an explicit scope for direct queries" do
    ::User.class_eval do
      must_scope_by :color, :taste

      scope :red, lambda { where(:favorite_color => 'red') }, :category => :color
      scope :green, lambda { where(:favorite_color => 'green') }, :category => :color

      scope :salty, lambda { where(:favorite_taste => 'salty') }, :category => :taste
      scope :sweet, lambda { where(:favorite_taste => 'sweet') }, :category => :taste
    end

    # ::User.class_eval do
    #   base_scope_required!

    #   base_scope :red, lambda { where(:favorite_color => 'red') }
    # end

    should_raise_missing_scopes(:exec_queries, [ :color, :taste ], [ ]) { ::User.all.to_a }
    should_raise_missing_scopes(:exec_queries, [ :color, :taste ], [ :color ]) { ::User.red.to_a }

    ::User.red.salty.to_a.should == [ @red_salty ]

    # ::User.all_colors.all_tastes.where(:name => 'User 1')
    # ::User.unscoped.where(:name => 'User 1')
  end
end
