require 'active_record'
require 'required_scopes/errors'

# This file simply adds a few small methods to ::ActiveRecord::Relation to allow tracking which scope categories have
# been satisfied on a relation.
::ActiveRecord::Relation.class_eval do
  # Tells this Relation that one or more categories have been satisfied.
  def required_scope_categories_satisfied!(categories)
    @scope_categories_satisfied ||= [ ]
    @scope_categories_satisfied |= categories
  end

  # Tells this Relation that _all_ categories have been satisfied.
  def all_required_scope_categories_satisfied!
    required_scope_categories_satisfied!(required_scope_categories)
  end

  # Returns the set of scope categories that have been satisfied.
  def scope_categories_satisfied
    @scope_categories_satisfied ||= [ ]
  end

  delegate :required_scope_categories, :to => :klass


  private
  # Raises an exception if there is at least one required scope category that has not yet been satisfied.
  # +triggering_method+ is the name of the method called that triggered this check; we include this in the error
  # we raise.
  def ensure_categories_satisfied!(triggering_method)
    required_categories = required_scope_categories
    missing_categories = required_categories - scope_categories_satisfied

    if missing_categories.length > 0
      # We return a special exception for the category +:base+, because we want to give a simpler, cleaner error
      # message for users who are just using the #base_scope_required! syntactic sugar instead of the full categories
      # system.
      if missing_categories == [ :base ]
        raise RequiredScopes::Errors::BaseScopeNotSatisfiedError.new(klass, self, triggering_method)
      else
        raise RequiredScopes::Errors::RequiredScopeCategoriesNotSatisfiedError.new(
          klass, self, triggering_method, required_categories, scope_categories_satisfied)
      end
    end
  end

  # Override certain key methods in ActiveRecord::Relation to make sure they check for category satisfaction before
  # running.
  [ :exec_queries, :perform_calculation, :update_all, :delete_all, :exists?, :pluck ].each do |method_name|
    method_base_name = method_name
    method_suffix = ""

    if method_base_name =~ /^(.*?)([\?\!])$/
      method_base_name = $1
      method_suffix = $2
    end

    define_method("#{method_base_name}_with_scope_categories_check#{method_suffix}") do |*args, &block|
      ensure_categories_satisfied!(method_name)
      send("#{method_base_name}_without_scope_categories_check#{method_suffix}", *args, &block)
    end

    alias_method_chain method_name, :scope_categories_check
  end
end
