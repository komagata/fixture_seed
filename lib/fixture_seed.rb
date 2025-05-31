# frozen_string_literal: true

require_relative "fixture_seed/version"
require_relative "fixture_seed/railtie" if defined?(Rails::Railtie)

module FixtureSeed
  class Error < StandardError; end

  class << self
    def load_fixtures
      fixture_dir = Rails.root.join("db/fixtures").to_s
      fixture_files = Dir.glob(File.join(fixture_dir, "*.yml"))

      return if fixture_files.empty?

      # Extract table names from fixture files
      table_names = fixture_files.map do |file|
        File.basename(file, ".*").sub(/\.yml$/, "")
      end.uniq

      Rails.logger.info "[FixtureSeed] Found #{fixture_files.size} fixture files for tables: #{table_names.join(', ')}"

      # Load all fixtures with retry logic
      unloaded_tables = process_fixtures_with_retry(fixture_dir, table_names)

      # Report any fixtures that still failed
      if unloaded_tables.empty?
        Rails.logger.info "[FixtureSeed] All fixtures loaded successfully."
      else
        message = "The following fixtures could not be loaded: #{unloaded_tables.join(', ')}"
        Rails.logger.warn "[FixtureSeed] #{message}"
      end
    end

    private

    def process_fixtures_with_retry(fixture_dir, table_names)
      remaining_tables = table_names.dup
      previous_count = remaining_tables.size + 1

      # Continue until all fixtures are loaded or no progress is made
      while !remaining_tables.empty? && remaining_tables.size < previous_count
        previous_count = remaining_tables.size
        remaining_tables = process_batch_with_fixture_set(fixture_dir, table_names, remaining_tables)
      end

      remaining_tables
    end

    def process_batch_with_fixture_set(fixture_dir, original_tables, current_tables)
      still_failed = []

      current_tables.each do |table_name|
        log_loading_table(table_name)
        load_single_table_fixture(fixture_dir, table_name)
        log_success_table(table_name, original_tables, current_tables)
      rescue ActiveRecord::InvalidForeignKey, ActiveRecord::StatementInvalid => e
        log_failure_table(table_name, e, original_tables, current_tables)
        still_failed << table_name
      end

      still_failed
    end

    def load_single_table_fixture(fixture_dir, table_name)
      # Use ActiveRecord::FixtureSet.create_fixtures for ERB support and other features
      ActiveRecord::FixtureSet.create_fixtures(fixture_dir, table_name)
    rescue ActiveRecord::InvalidForeignKey, ActiveRecord::StatementInvalid => e
      # Re-raise to be caught by the retry logic
      raise e
    rescue StandardError => e
      # Convert other errors to InvalidForeignKey for retry logic
      raise ActiveRecord::InvalidForeignKey, e.message
    end

    def log_loading_table(table_name)
      Rails.logger.info "[FixtureSeed] Loading fixture for table #{table_name}..."
    end

    def log_success_table(table_name, original_tables, current_tables)
      is_retry = original_tables.size != current_tables.size
      message = if is_retry
                  "[FixtureSeed] Successfully loaded fixture for table #{table_name} on retry."
                else
                  "[FixtureSeed] Loaded fixture for table #{table_name}"
                end
      Rails.logger.info message
    end

    def log_failure_table(table_name, error, original_tables, current_tables)
      is_retry = original_tables.size != current_tables.size
      message = if is_retry
                  "[FixtureSeed] Still failed to load fixture for table #{table_name}: #{error.message}. Will retry later."
                else
                  "[FixtureSeed] Failed to load fixture for table #{table_name}: #{error.message}. Will retry later."
                end
      Rails.logger.warn message
    end
  end
end
