# There's currently nothing at all in the RequiredScopes module except for its use as a namespace.
module RequiredScopes
end

require "required_scopes/version"
require "required_scopes/active_record/base"
require "active_record"

# Add methods to ::ActiveRecord::Base that let you declare scoping requirements, and declare scopes that satisfy
# them...
ActiveRecord::Base.send(:include, ::RequiredScopes::ActiveRecord::Base)

# ...and add methods to ::ActiveRecord::Relation that enforce those requirements.
require "required_scopes/active_record/relation"

require "required_scopes/active_record/version_compatibility"
::RequiredScopes::ActiveRecord::VersionCompatibility.apply_version_specific_fixes!
