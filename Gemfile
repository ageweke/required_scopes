source 'https://rubygems.org'

# Specify your gem's dependencies in required_scopes.gemspec
gemspec

ar_version = ENV['REQUIRED_SCOPES_AR_TEST_VERSION']
ar_version = ar_version.strip if ar_version

version_spec = case ar_version
when nil then nil
when 'master' then { :git => 'git://github.com/rails/activerecord.git' }
else "=#{ar_version}"
end

if version_spec
  gem("activerecord", version_spec)
end
