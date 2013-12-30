require "require_explicit_scope/version"
require "require_explicit_scope/active_record/base"
require "active_record"

module RequireExplicitScope
  # Your code goes here...
end

ActiveRecord::Base.send(:include, RequireExplicitScope::ActiveRecord::Base)

class ActiveRecord::Relation
  def has_base_scope!
    $stderr.puts "has_base_scope! (#{object_id})"
    @_has_base_scope = true
  end

  def ensure_has_base_scope!
    if klass.explicit_scope_required? && (! @_has_base_scope)
      raise "You must include an explicit scope here, for class #{klass.name}; relation: (#{object_id})"
    end
  end

  def exec_queries_with_base_scope_check(*args)
    ensure_has_base_scope!
    exec_queries_without_base_scope_check(*args)
  end

  alias_method_chain :exec_queries, :base_scope_check
end
