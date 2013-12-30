require 'active_record'
require 'active_record/migration'

module RequireExplicitScope
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
          end
        end
      end

      def create_standard_system_spec_models!
        define_model_class(:User, 'rec_spec_users') { }
      end

      def drop_standard_system_spec_tables!
        migrate do
          drop_table :rec_spec_users rescue nil
        end
      end
    end
  end
end
