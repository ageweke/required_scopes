require 'active_support'

module RequireExplicitScope
  module ActiveRecord
    module Base
      extend ActiveSupport::Concern

      module ClassMethods
        def require_explicit_scope
          $stderr.puts "explicit scope required on #{self.name}"
        end
      end
    end
  end
end
