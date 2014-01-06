require 'active_support'

module RequiredScopes
  module ActiveRecord
    # This is the module that gets +include+d into ::ActiveRecord::Base when +required_scopes+ is loaded. It defines
    # the exposed methods on ::ActiveRecord::Base, and overrides a few (like #scope and #unscoped).
    module Base
      extend ActiveSupport::Concern

      included do
        class << self
          delegate :satisfying_category, :satisfying_categories, :to => :relation
        end
      end

      module ClassMethods
        # Declares that all users of your model must scope it by one or more categories when running a query, performing
        # a calculation (like #count or #exists?), or running certain bulk-update statements (like #delete_all).
        # Categories are simply symbols, and they are considered satisfied if a scope is used that declares (_e.g._)
        # <tt>:satisfies => :deletion</tt> is included before running a query.
        #
        # This is the heart of +required_scopes+. Its purpose is to remind developers that certain kinds of constraints
        # should always be taken into account when accessing data in a particular table, so that they can't
        # under-constrain queries and potentially ignore soft deletion of rows, or cross client boundaries, or similar
        # things.
        #
        # For example:
        #
        #     class User < ActiveRecord::Base
        #       must_scope_by :deletion
        #
        #       scope :normal, lambda { where(:deleted => false) }, :satisfies => :deletion
        #       scope :deleted, lambda { where(:deleted => true) }, :satisfies => :deletion
        #     end
        #
        # Now, if you say
        #
        #     the_user = User.where(:name => 'foo').first
        #
        # ...you'll get a RequiredScopes::Errors::RequiredScopeCategoriesNotSatisfiedError; you must instead call
        # one of these:
        #
        #     the_user = User.normal.where(:name => 'foo').first
        #     the_user = User.deleted.where(:name => 'foo').first
        #
        # For any given scope category, a scope starting with +ignoring_+ is automatically created; this does not
        # actually constrain the scope in any way, but marks that category as satisfied. (The point is not to _force_
        # developers to constrain on something, but to make sure they can't simply forget about the category.) So this
        # will also work:
        #
        #     the_user = User.ignoring_deletion.where(:name => 'foo').first
        #
        # An explicit call to #unscoped removes all requirements, whether used in its direct form or its
        # block form, so these will also both work:
        #
        #     the_user = User.unscoped.where(:name => 'foo').first
        #     User.unscoped { the_user = User.where(:name => 'foo').first }
        #
        # ActiveRecord also lets you use class methods as scopes; if you want one of these to count as satisfying a
        # scope category, use #satisfying_category (or #satisfying_categories):
        #
        #     class User < ActiveRecord::Base
        #       must_scope_by :client
        #
        #       scope :active_clients, lambda { where(:client_active => true) }, :satisfies => :client
        #
        #       class << self
        #         def for_client_named(client_name)
        #           client_id = CLIENT_MAP[client_name]
        #           where(:client_id => client_id).satisfying_category(:client)
        #         end
        #       end
        #     end
        #
        # In the above example, either <tt>User.active_clients.first</tt> or <tt>User.for_client_named('foo').first</tt>
        # will count as having satisfied the requirement to scope by +:client+, and hence will not raise an error.
        def must_scope_by(*args)
          categories = args.map(&:to_sym)
          @required_scope_categories ||= [ ]
          @required_scope_categories += categories

          categories.each do |category|
            scope "ignoring_#{category}", lambda { all }, :satisfies => category
          end
        end

        # Overrides ActiveRecord::Base#unscoped to remove all category requirements. If you explicitly ask for something
        # to be unscoped, you've presumably thought about scoping, after all. :)
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

        # Returns the set of scope categories that must be satisfied for this class, as a (possibly-empty) Array.
        def required_scope_categories
          if self == ::ActiveRecord::Base
            [ ]
          else
            out = (@required_scope_categories || [ ]) | superclass.required_scope_categories
            out - (@ignored_parent_scope_requirements || [ ])
          end
        end

        # If you're using inheritance in your ActiveRecord::Base classes, and a parent class declares a required scope
        # category (using #must_scope_by), you can remove that requirement in a subclass using
        # #ignore_parent_scope_requirement. (This should be quite rare.)
        def ignore_parent_scope_requirement(*args)
          categories = args.map(&:to_sym)
          @ignored_parent_scope_requirements ||= [ ]
          @ignored_parent_scope_requirements |= categories
        end




        # Declares that use of this ActiveRecord::Base class must be scoped by at least one _base scope_; a base scope
        # is any scope declared using #base_scope, instead of #scope. (Other than satisfying this requirement,
        # #base_scope behaves identically to #scope.) This can be used to ensure that developers don't forget to scope
        # out deleted records, or don't forget to scope by client, or so forth. (See the +README+ for +required_scopes+
        # for why this is a better solution in many cases than just using +default_scope+.)
        #
        # For example:
        #
        #     class User < ActiveRecord::Base
        #       base_scope_required!
        #
        #       base_scope :undeleted { where(:deleted => false) }
        #       base_scope :deleted { where(:deleted => true) }
        #     end
        #
        # Now, you'll get the following:
        #
        #     User.where(...).first               # RequiredScopes::Errors::BaseScopeNotSatisfiedError
        #
        #     User.undeleted.where(...).first     # => SELECT * FROM users WHERE deleted = 0 AND ... LIMIT 1
        #     User.deleted.where(...).first       # => SELECT * FROM users WHERE deleted = 1 AND ... LIMIT 1
        #     User.ignoring_base.where(...).first # => SELECT * FROM users WHERE ... LIMIT 1
        #
        # (This is simply syntactic sugar on top of #must_scope_by, using a category name of +:base+; see that method
        # for more details.)
        def base_scope_required!
          must_scope_by :base
        end

        # Declares a scope that satisfies the requirement introduced by #base_scope_required!. In all other ways, it
        # behaves identically to ActiveRecord::Base#scope.
        def base_scope(name, body, &block)
          scope(name, body, :satisfies => :base, &block)
        end

        # Returns a scope identical to the one it's called on, but that's marked as satisfying the requirement
        # introduced by #base_scope_required!. This is useful in class methods that return a scope you want to count
        # as satisfying that requirement:
        #
        #     class User < ActiveRecord::Base
        #       base_scope_required!
        #
        #       class << self
        #         def for_client_named(c)
        #           where(:client_id => CLIENT_ID_TO_NAME_MAP[c]).satisfying_base_scope
        #         end
        #       end
        #     end
        def satisfying_base_scope
          satisfying_category(:base)
        end


        # Overrides ActiveRecord::Base#scope to mark a scope as satisfying one or more categories if an extra option
        # is passed:
        #
        #     scope :foo, lambda { ... }, :satisfies => :deletion
        #
        # You can also pass an Array of category names to :satisfies.
        def scope(name, body, *args, &block)
          if args && args[-1] && args[-1].kind_of?(Hash)
            opts = args.pop

            categories = Array(opts.delete(:satisfies)).compact

            if categories && categories.length > 0
              if body.kind_of?(Proc)
                # New, happy, dynamic scopes -- i.e., scope :foo, lambda { where(...) }
                old_body = body
                body = lambda do
                  out = old_body.call
                  out.required_scope_categories_satisfied!(categories)
                  out
                end
              else
                # Old, sad, static scopes -- i.e., scope :foo, where(...)
                body = body.clone
                body.required_scope_categories_satisfied!(categories)
                body
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
