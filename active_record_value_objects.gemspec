lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "active_record_value_objects/version"

Gem::Specification.new do |spec|
  spec.name = "active_record_value_objects"
  spec.version = ActiveRecordValueObjects::VERSION
  spec.authors = ["Joe Gaudet"]
  spec.email = ["joe@joegaudet.com"]

  spec.summary = "Store value objects in ActiveRecord jsonb columns"
  spec.description = "This gem allows you to store value objects in ActiveRecord models on jsonb columns."
  spec.homepage = "https://github.com/joegaudet/active_record_value_objects"
  spec.license = "MIT"

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the 'allowed_push_host'
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  if spec.respond_to?(:metadata)
    spec.metadata["allowed_push_host"] = "https://rubygems.org"

    spec.metadata["homepage_uri"] = spec.homepage
    spec.metadata["source_code_uri"] = "https://github.com/joegaudet/active_record_value_objects"
    spec.metadata["changelog_uri"] = "https://github.com/joegaudet/active_record_value_objects/CHANGELOG.md"
  else
    raise "RubyGems 2.0 or newer is required to protect against " \
            "public gem pushes."
  end

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(File.expand_path('..', __FILE__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency 'dry-struct', '~> 1.0'
  spec.add_dependency 'dry-types', '~> 1.8'
  spec.add_dependency 'terminal-table', '~> 1.8'
  spec.add_dependency 'activemodel', '~> 7.1'
  spec.add_dependency 'rails', '~> 7.1'
  spec.add_dependency 'mutex_m', '~> 0.1.0'
  spec.add_dependency 'base64', '~> 0.2.0'

  spec.add_development_dependency 'bundler', '~> 2.6.2'
  spec.add_development_dependency 'rake', '~> 13.0'
  spec.add_development_dependency 'rspec', '~> 3.0'
  spec.add_development_dependency 'faker', '~> 2.18'
end
