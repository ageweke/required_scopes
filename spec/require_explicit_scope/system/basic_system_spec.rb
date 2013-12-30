require 'require_explicit_scope'
require 'require_explicit_scope/helpers/database_helper'
require 'require_explicit_scope/helpers/system_helpers'

require 'pry'

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
      require_explicit_scope

      scope :red, lambda { where(:favorite_color => 'red') }, :base => true
    end

    show("::User.where(:name => 'User 1').to_a")
    show("::User.red.where(:name => 'User 1').to_a")
  end
end
