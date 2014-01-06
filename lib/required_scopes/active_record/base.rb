require 'active_support'

module RequiredScopes
  module ActiveRecord
    module Base
      extend ActiveSupport::Concern

      module ClassMethods
        def must_scope_by(*args)
          categories = args.map(&:to_sym)
          @required_scope_categories ||= [ ]
          @required_scope_categories += categories

          categories.each do |category|
            scope "ignoring_#{category}", lambda { all }, :category => category
          end
        end

        def unscoped(&block)
          if block
            super do
              current_scope.all_required_scope_categories_satisfied!
              block.call
            end
          else
            out = super
            out.all_required_scope_categories_satisfied!
            out
          end
        end

        def satisfying_categories(*categories)
          out = all
          out.required_scope_categories_satisfied!(categories)
          out
        end

        def satisfying_category(category)
          satisfying_categories(category)
        end

        def required_scope_categories
          if self == ::ActiveRecord::Base
            [ ]
          else
            out = (@required_scope_categories || [ ]) | superclass.required_scope_categories
            out - (@ignored_parent_scope_requirements || [ ])
          end
        end

        def ignore_parent_scope_requirement(*args)
          categories = args.map(&:to_sym)
          @ignored_parent_scope_requirements ||= [ ]
          @ignored_parent_scope_requirements |= categories
        end



        def scope(name, body, *args, &block)
          if args && args[-1] && args[-1].kind_of?(Hash)
            opts = args.pop

            categories = (Array(opts.delete(:categories)) + [ opts.delete(:category) ]).compact

            if categories
              unless body.kind_of?(Proc)
                raise RequiredScopes::Errors::CategoryScopesMustBeDefinedAsProcError,
                  %{If you declare a scope as satisfying one or more required categories (here, #{categories.inspect}),
you must define the body of the scope as a Proc/lambda, not by immediately passing
a scope. (The latter form is deprecated as of Rails 4 anyway.)

This is because we need to mark the scope as satisfied at runtime, and we can only
do that if we have a block to put the code into.

Offending scope: #{name.inspect}}
              end

              old_body = body
              body = lambda do
                out = old_body.call
                out.required_scope_categories_satisfied!(categories)
                out
              end
            end

            args.push(opts) if opts.size > 0
          end

          super(name, body, &block)
        end
      end
    end
  end
end
