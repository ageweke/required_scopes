require 'active_support'

module RequireExplicitScope
  module ActiveRecord
    module Base
      extend ActiveSupport::Concern

      module ClassMethods
        def require_explicit_scope
          @_explicit_scope_required = true
        end

        def explicit_scope_required?
          !! @_explicit_scope_required
        end

        def scope(name, body, *more)
          if more && more[-1] && more[-1].kind_of?(Hash)
            opts = more.pop
            if opts.delete(:base) && body.kind_of?(Proc)
              return super(name, lambda { out = body.call; out.has_base_scope!; out }, *more)
            end

            more.push(opts) if opts.size > 0
          end

          super(name, body, *more, &block)
        end
      end
    end
  end
end
