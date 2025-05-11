# frozen_string_literal: true

require_relative "lib/fixture_seed/version"

Gem::Specification.new do |spec|
  spec.name = "fixture_seed"
  spec.version = FixtureSeed::VERSION
  spec.authors = ["Devin AI"]
  spec.email = ["158243242+devin-ai-integration[bot]@users.noreply.github.com"]

  spec.summary = "A Rails gem to automatically load fixtures from db/fixtures directory during db:seed"
  spec.description = "fixture_seed is a Rails gem that automatically loads YAML fixtures from db/fixtures directory in alphabetical order when running rails db:seed, with error handling for foreign key constraints."
  spec.homepage = "https://github.com/komagata/fixture_seed"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 2.6.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/komagata/fixture_seed"
  spec.metadata["changelog_uri"] = "https://github.com/komagata/fixture_seed/blob/main/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject do |f|
      (f == __FILE__) || f.match(%r{\A(?:(?:bin|test|spec|features)/|\.(?:git|travis|circleci)|appveyor)})
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Register dependencies
  spec.add_dependency "rails", ">= 5.0"

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
end
