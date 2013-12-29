require "require_explicit_scope/version"
require "require_explicit_scope/active_record/base"
require "active_record"

module RequireExplicitScope
  # Your code goes here...
end

ActiveRecord::Base.send(:include, RequireExplicitScope::ActiveRecord::Base)
