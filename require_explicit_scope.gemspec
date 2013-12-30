# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'required_scopes/version'

Gem::Specification.new do |s|
  s.name          = "required_scopes"
  s.version       = RequiredScopes::VERSION
  s.authors       = ["Andrew Geweke"]
  s.email         = ["andrew@geweke.org"]
  s.description   = %q{Require an explicit scope for all queries to a table.}
  s.summary       = %q{Require an explicit scope for all queries to a table.}
  s.homepage      = "https://github.com/ageweke/required_scopes"
  s.license       = "MIT"

  s.files         = `git ls-files`.split($/)
  s.executables   = s.files.grep(%r{^bin/}) { |f| File.basename(f) }
  s.test_files    = s.files.grep(%r{^(test|spec|features)/})
  s.require_paths = ["lib"]

  s.add_development_dependency "bundler", "~> 1.3"
  s.add_development_dependency "rake"
  s.add_development_dependency "rspec", "~> 2.14"

  if (RUBY_VERSION =~ /^1\.9\./ || RUBY_VERSION =~ /^2\./) && ((! defined?(RUBY_ENGINE)) || (RUBY_ENGINE != 'jruby'))
    s.add_development_dependency "pry"
    s.add_development_dependency "pry-debugger"
    s.add_development_dependency "pry-stack_explorer"
  end

  ar_version = ENV['REQUIRED_SCOPES_AR_TEST_VERSION']
  ar_version = ar_version.strip if ar_version

  version_spec = case ar_version
  when nil then [ ">= 3.0", "<= 4.99.99" ]
  when 'master' then nil
  else [ "=#{ar_version}" ]
  end

  if version_spec
    s.add_dependency("activerecord", *version_spec)
  end

  s.add_dependency "activesupport", ">= 3.0", "<= 4.99.99"

  require File.expand_path(File.join(File.dirname(__FILE__), 'spec', 'required_scopes', 'helpers', 'database_helper'))
  database_gem_name = RequiredScopes::Helpers::DatabaseHelper.maybe_database_gem_name

  # Ugh. Later versions of the 'mysql2' gem are incompatible with AR 3.0.x; so, here, we explicitly trap that case
  # and use an earlier version of that Gem.
  if database_gem_name && database_gem_name == 'mysql2' && ar_version && ar_version =~ /^3\.0\./
    s.add_development_dependency('mysql2', '~> 0.2.0')
  else
    s.add_development_dependency(database_gem_name)
  end
end
