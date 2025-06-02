# frozen_string_literal: true

require "active_record"
require "active_record/fixtures"

module FixtureSeed
  class Loader
    DEFAULT_FIXTURES_PATH = "db/fixtures"

    class << self
      def load_fixtures(fixtures_path = nil)
        fixtures_path ||= ENV["FIXTURES_PATH"] || DEFAULT_FIXTURES_PATH
        fixtures_dir = Rails.root.join(fixtures_path)

        return unless fixtures_directory_exists?(fixtures_dir, fixtures_path)

        load_fixture_files(fixtures_dir, fixtures_path)
      end

      private

      def fixtures_directory_exists?(fixtures_dir, fixtures_path)
        return true if Dir.exist?(fixtures_dir)

        Rails.logger&.info "[FixtureSeed] Fixtures directory not found: #{fixtures_path}"
        false
      end

      def load_fixture_files(fixtures_dir, fixtures_path)
        Rails.logger&.info "[FixtureSeed] Loading fixtures from #{fixtures_path}"

        fixture_files = Dir.glob("#{fixtures_dir}/*.yml")
        return if fixture_files.empty?

        table_names = fixture_files.map { |f| File.basename(f, ".yml") }
        Rails.logger&.info "[FixtureSeed] Found tables: #{table_names.join(', ')}"

        # Check if FixtureSet is available
        unless defined?(ActiveRecord::FixtureSet)
          Rails.logger&.error "[FixtureSeed] ActiveRecord::FixtureSet is not available. Please ensure you're using Rails 4.0+ or include 'active_record/fixtures'."
          return
        end

        ActiveRecord::Base.connection.disable_referential_integrity do
          ActiveRecord::FixtureSet.create_fixtures(fixtures_dir.to_s, table_names)
        end

        Rails.logger&.info "[FixtureSeed] Finished loading fixtures"
      end
    end
  end
end
