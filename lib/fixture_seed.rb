# frozen_string_literal: true

require_relative "fixture_seed/version"
require_relative "fixture_seed/railtie" if defined?(Rails::Railtie)

module FixtureSeed
  class Error < StandardError; end

  class << self
    def load_fixtures
      fixture_dir = Rails.root.join("db/fixtures").to_s
      files_to_load = Dir.glob(File.join(fixture_dir, "*.yml")).sort

      file_names = files_to_load.map { |f| File.basename(f) }.join(", ")
      Rails.logger.info "[FixtureSeed] Found #{files_to_load.size} fixture files in #{fixture_dir}: #{file_names}"

      # Load all fixtures with retry logic
      unloaded_files = process_fixtures(fixture_dir, files_to_load)

      # Report any fixtures that still failed
      if unloaded_files.empty?
        Rails.logger.info "[FixtureSeed] All fixtures loaded successfully."
      else
        message = "The following fixtures could not be loaded: #{unloaded_files.join(', ')}"
        Rails.logger.warn "[FixtureSeed] #{message}"
      end
    end

    private

    def process_fixtures(fixture_dir, files)
      remaining_files = files.dup
      previous_count = remaining_files.size + 1

      # Continue until all fixtures are loaded or no progress is made
      while !remaining_files.empty? && remaining_files.size < previous_count
        previous_count = remaining_files.size
        remaining_files = process_batch(fixture_dir, files, remaining_files)
      end

      remaining_files
    end

    def process_batch(fixture_dir, original_files, current_files)
      still_failed = []

      current_files.each do |file|
        log_loading(file)
        load_single_fixture(fixture_dir, file)
        log_success(file, original_files, current_files)
      rescue ActiveRecord::InvalidForeignKey, ActiveRecord::StatementInvalid => e
        log_failure(file, e, original_files, current_files)
        still_failed << file
      end

      still_failed
    end

    def load_single_fixture(_fixture_dir, file)
      table_name = File.basename(file, ".yml")
      yaml_data = YAML.load_file(file)

      model_class = begin
        table_name.classify.constantize
      rescue StandardError
        nil
      end

      if model_class
        yaml_data.each do |_fixture_name, attributes|
          model_class.create!(attributes)
        rescue StandardError => e
          raise ActiveRecord::InvalidForeignKey, e.message
        end
      else
        Rails.logger.warn "[FixtureSeed] Model for table #{table_name} not found"
      end
    end

    def log_loading(file)
      Rails.logger.info "[FixtureSeed] Loading fixture #{File.basename(file)}..."
    end

    def log_success(file, original_files, current_files)
      is_retry = original_files.size != current_files.size
      if is_retry
        Rails.logger.info "[FixtureSeed] Successfully loaded fixture #{File.basename(file)} on retry."
      else
        Rails.logger.info "[FixtureSeed] Loaded fixture #{File.basename(file)}"
      end
    end

    def log_failure(file, error, original_files, current_files)
      is_retry = original_files.size != current_files.size
      filename = File.basename(file)
      if is_retry
        Rails.logger.warn "[FixtureSeed] Still failed to load fixture #{filename}: " \
                          "#{error.message}. Will retry later."
      else
        Rails.logger.warn "[FixtureSeed] Failed to load fixture #{filename}: " \
                          "#{error.message}. Will retry later."
      end
    end
  end
end
