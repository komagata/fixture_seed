# frozen_string_literal: true

require_relative "lib/fixture_seed/version"

Gem::Specification.new do |spec|
  spec.name = "fixture_seed"
  spec.version = FixtureSeed::VERSION
  spec.authors = ["Masaki Komagata"]
  spec.email = ["komagata@gmail.com"]

  spec.summary = "A Rails gem to automatically load fixtures from db/fixtures directory during db:seed"
  spec.description = "fixture_seed is a Rails gem that automatically loads YAML fixtures from db/fixtures " \
                     "directory in alphabetical order when running rails db:seed, with error handling for " \
                     "foreign key constraints."
  spec.homepage = "https://github.com/komagata/fixture_seed"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 2.6.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/komagata/fixture_seed"
  spec.metadata["changelog_uri"] = "https://github.com/komagata/fixture_seed/blob/main/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"

  # Specify which files should be added to the gem when it is released.
  spec.files = Dir[
    "lib/**/*.rb",
    "sig/**/*.rbs",
    "LICENSE.txt",
    "README.md",
    "CHANGELOG.md"
  ]

  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Register dependencies
  spec.add_dependency "rails", ">= 5.0"

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
end
