require 'active_record'
require 'required_scopes/errors'

::ActiveRecord::Relation.class_eval do
  def required_scope_categories_satisfied!(categories)
    @scope_categories_satisfied ||= [ ]
    @scope_categories_satisfied |= categories
  end

  def all_required_scope_categories_satisfied!
    required_scope_categories_satisfied!(required_scope_categories)
  end

  def scope_categories_satisfied
    @scope_categories_satisfied ||= [ ]
  end

  delegate :required_scope_categories, :to => :klass


  private
  def ensure_categories_satisfied!(triggering_method)
    required_categories = required_scope_categories
    missing_categories = required_categories - scope_categories_satisfied

    if missing_categories.length > 0
      raise RequiredScopes::Errors::RequiredScopeCategoriesNotSatisfiedError.new(
        klass, self, triggering_method, required_categories, scope_categories_satisfied)
    end
  end

  [ :exec_queries, :perform_calculation, :update_all, :delete_all, :exists? ].each do |method_name|
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
