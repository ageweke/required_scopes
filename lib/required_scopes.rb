require "required_scopes/version"
require "required_scopes/active_record/base"
require "active_record"

module RequiredScopes
  # Your code goes here...
end

ActiveRecord::Base.send(:include, RequiredScopes::ActiveRecord::Base)

require "required_scopes/active_record/relation"
