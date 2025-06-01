# frozen_string_literal: true

require_relative "fixture_seed/version"
require_relative "fixture_seed/loader"
require_relative "fixture_seed/railtie" if defined?(Rails::Railtie)

module FixtureSeed
  class Error < StandardError; end

  def self.load_fixtures(fixtures_path = nil)
    Loader.load_fixtures(fixtures_path)
  end
end
