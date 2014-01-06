require 'active_record'
require 'active_record/migration'

module RequiredScopes
  module Helpers
    module SystemHelpers
      def migrate(&block)
        migration_class = Class.new(::ActiveRecord::Migration)
        metaclass = migration_class.class_eval { class << self; self; end }
        metaclass.instance_eval { define_method(:up, &block) }

        ::ActiveRecord::Migration.suppress_messages do
          migration_class.migrate(:up)
        end
      end

      def define_model_class(name, table_name, &block)
        model_class = Class.new(::ActiveRecord::Base)
        ::Object.send(:remove_const, name) if ::Object.const_defined?(name)
        ::Object.const_set(name, model_class)
        model_class.table_name = table_name
        model_class.class_eval(&block)
      end

      def create_standard_system_spec_tables!
        migrate do
          drop_table :rec_spec_users rescue nil
          create_table :rec_spec_users do |t|
            t.string :name, :null => false
            t.string :favorite_color
            t.string :favorite_taste
          end
        end
      end

      def define_color_and_taste_scopes!
        ::User.class_eval do
          must_scope_by :color, :taste

          scope :red, lambda { where(:favorite_color => 'red') }, :satisfies => :color
          scope :green, lambda { where(:favorite_color => 'green') }, :satisfies => :color

          scope :salty, lambda { where(:favorite_taste => 'salty') }, :satisfies => :taste
          scope :sweet, lambda { where(:favorite_taste => 'sweet') }, :satisfies => :taste

          scope :red_and_salty, lambda { where(:favorite_color => 'red', :favorite_taste => 'salty') }, :satisfies => [ :color, :taste ]
        end
      end

      def should_raise_missing_scopes(triggering_method, required, satisfied, options = { })
        e = result = nil

        begin
          result = yield
        rescue RequiredScopes::Errors::RequiredScopeCategoriesNotSatisfiedError => rscnse
          e = rscnse
        end

        raise "Expected a scopes-not-satisfied error, but got none" unless e

        expected_model_class = options[:model_class] || ::User

        e.class.should == RequiredScopes::Errors::RequiredScopeCategoriesNotSatisfiedError
        e.model_class.should == expected_model_class
        e.current_relation.should be
        e.current_relation.kind_of?(::ActiveRecord::Relation).should be
        e.triggering_method.should == triggering_method
        e.required_categories.sort_by(&:to_s).should == required.sort_by(&:to_s)
        e.satisfied_categories.sort_by(&:to_s).should == satisfied.sort_by(&:to_s)

        expected_missing_categories = required - satisfied
        e.missing_categories.sort_by(&:to_s).should == expected_missing_categories.sort_by(&:to_s)

        e.message.should match(/#{expected_model_class.name}/)
        e.message.should match(/#{expected_missing_categories.sort_by(&:to_s).join(", ")}/)
      end

      def create_standard_system_spec_models!
        define_model_class(:User, 'rec_spec_users') { }
      end

      def create_standard_system_spec_instances!
        @red_salty = ::User.create!(:name => 'red-salty', :favorite_color => 'red', :favorite_taste => 'salty')
        @green_salty = ::User.create!(:name => 'green-salty', :favorite_color => 'green', :favorite_taste => 'salty')
        @blue_salty = ::User.create!(:name => 'blue-salty', :favorite_color => 'blue', :favorite_taste => 'salty')
        @red_sweet = ::User.create!(:name => 'red-sweet', :favorite_color => 'red', :favorite_taste => 'sweet')
        @green_sweet = ::User.create!(:name => 'green-sweet', :favorite_color => 'green', :favorite_taste => 'sweet')
        @blue_sweet = ::User.create!(:name => 'blue-sweet', :favorite_color => 'blue', :favorite_taste => 'sweet')
      end

      def drop_standard_system_spec_tables!
        migrate do
          drop_table :rec_spec_users rescue nil
        end
      end
    end
  end
end
