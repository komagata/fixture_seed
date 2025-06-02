# frozen_string_literal: true

require "active_record"
require "active_record/fixtures"

module FixtureSeed
  class Loader
    DEFAULT_FIXTURES_PATH = "db/fixtures"

    class << self
      def load_fixtures(fixtures_path = nil)
        fixtures_path ||= ENV["FIXTURES_PATH"] || "db/fixtures"
        fixtures_dir = Rails.root.join(fixtures_path)
        fixture_names = discover_fixture_names(fixtures_dir)

        ActiveRecord::Base.connection.disable_referential_integrity do
          ActiveRecord::FixtureSet.create_fixtures(fixtures_dir.to_s, fixture_names)
        end
      end

      private

      def discover_fixture_names(fixtures_dir)
        fixture_files = Dir[File.join(fixtures_dir, "**/*.yml")]
        fixture_files.map do |file|
          file[fixtures_dir.to_s.size..-5].delete_prefix("/")
        end
      end
    end
  end
end
