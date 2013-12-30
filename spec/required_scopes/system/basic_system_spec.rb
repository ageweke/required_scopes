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

  it "should allow requiring an explicit scope for direct queries" do
    ::User.class_eval do
      require_scopes

      scope :red, lambda { where(:favorite_color => 'red') }, :base => true
    end

    show("::User.where(:name => 'User 1').to_a")
    show("::User.red.where(:name => 'User 1').to_a")
  end
end
