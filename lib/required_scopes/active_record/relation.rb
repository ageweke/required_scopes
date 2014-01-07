require 'active_record'
require 'required_scopes/errors'
require 'required_scopes/active_record/version_compatibility'

# This file simply adds a few small methods to ::ActiveRecord::Relation to allow tracking which scope categories have
# been satisfied on a relation.
::ActiveRecord::Relation.class_eval do
  # Call this method inline, exactly as you would any class-defined scope, to indicate that a particular category
  # or categories have been satisfied. It's really intended for use in a class method, but both of these will
  # work:
  #
  #     class User < ActiveRecord::Base
  #       must_scope_by :client, :deleted
  #
  #       class << self
  #         def active_for_client_named(client_name)
  #           client_id = CLIENT_MAP[client_name]
  #           where(:client_id => client_id).where(:deleted => false).scope_categories_satisfied(:client)
  #         end
  #       end
  #     end
  #
  #     User.active_for_client_named('foo').first
  #     User.where(:client_id => client_id).where(:deleted => false).scope_categories_satisfied(:client, :deleted).first
  def scope_categories_satisfied(*categories, &block)
    categories = categories.flatten

    new_scope = if categories.length == 0
      self
    else
      out = clone
      out.scope_categories_satisfied!(categories)
      out
    end

    if block
      new_scope.scoping(&block)
    else
      new_scope
    end
  end

  # Alias for #scope_categories_satisfied.
  def scope_category_satisfied(category, &block)
    scope_categories_satisfied(category, &block)
  end

  # Tells this Relation that one or more categories have been satisfied.
  def scope_categories_satisfied!(categories)
    categories = categories.flatten

    @satisfied_scope_categories ||= [ ]
    @satisfied_scope_categories |= categories
  end

  # Tells this Relation that _all_ categories have been satisfied.
  def all_scope_categories_satisfied!
    scope_categories_satisfied!(required_scope_categories)
  end

  def all_scope_categories_satisfied(&block)
    scope_categories_satisfied(required_scope_categories, &block)
  end

  # Returns the set of scope categories that have been satisfied.
  def satisfied_scope_categories
    @satisfied_scope_categories ||= [ ]
  end

  # Overrides #merge to merge the information about which scope categories have been satisfied, too.
  def merge(other_relation)
    super.scope_categories_satisfied(satisfied_scope_categories | other_relation.satisfied_scope_categories)
  end

  delegate :required_scope_categories, :to => :klass


  private
  # Raises an exception if there is at least one required scope category that has not yet been satisfied.
  # +triggering_method+ is the name of the method called that triggered this check; we include this in the error
  # we raise.
  def ensure_categories_satisfied!(triggering_method)
    required_categories = required_scope_categories
    missing_categories = required_categories - satisfied_scope_categories

    if missing_categories.length > 0
      # We return a special exception for the category +:base+, because we want to give a simpler, cleaner error
      # message for users who are just using the #base_scope_required! syntactic sugar instead of the full categories
      # system.
      # $stderr.puts "RAISING AT: #{caller.join("\n    ")}"
      if missing_categories == [ :base ]
        raise RequiredScopes::Errors::BaseScopeNotSatisfiedError.new(klass, self, triggering_method)
      else
        raise RequiredScopes::Errors::RequiredScopeCategoriesNotSatisfiedError.new(
          klass, self, triggering_method, required_categories, satisfied_scope_categories)
      end
    end
  end

  # Override certain key methods in ActiveRecord::Relation to make sure they check for category satisfaction before
  # running.
  [ :exec_queries, :perform_calculation, :update_all, :delete_all, :exists?, :pluck ].each do |method_name|
    method_base_name = method_name
    method_suffix = ""

    if method_base_name.to_s =~ /^(.*?)([\?\!])$/
      method_base_name = $1
      method_suffix = $2
    end

    with_name = "#{method_base_name}_with_scope_categories_check#{method_suffix}"
    without_name = "#{method_base_name}_without_scope_categories_check#{method_suffix}"

    define_method(with_name) do |*args, &block|
      ensure_categories_satisfied!(method_name) unless RequiredScopes::ActiveRecord::VersionCompatibility.is_association_relation?(self)
      send(without_name, *args, &block)
    end

    alias_method_chain method_name, :scope_categories_check
  end
end
