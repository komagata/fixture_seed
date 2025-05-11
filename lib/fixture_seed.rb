# frozen_string_literal: true

require_relative "fixture_seed/version"
require_relative "fixture_seed/railtie" if defined?(Rails)

module FixtureSeed
  class Error < StandardError; end
  
  class << self
    def load_fixtures
      fixture_files = Dir.glob(File.join(Rails.root, 'db', 'fixtures', '*.yml')).sort
      failed_fixtures = []
      
      # First pass: try to load all fixtures
      fixture_files.each do |file|
        begin
          load_fixture(file)
        rescue ActiveRecord::InvalidForeignKey, ActiveRecord::StatementInvalid => e
          Rails.logger.info "Failed to load fixture #{file}: #{e.message}. Will retry later."
          failed_fixtures << file
        end
      end
      
      # Retry failed fixtures until all are loaded or no progress is made
      previous_failed_count = failed_fixtures.size + 1
      while !failed_fixtures.empty? && failed_fixtures.size < previous_failed_count
        previous_failed_count = failed_fixtures.size
        still_failed = []
        
        failed_fixtures.each do |file|
          begin
            load_fixture(file)
            Rails.logger.info "Successfully loaded fixture #{file} on retry."
          rescue ActiveRecord::InvalidForeignKey, ActiveRecord::StatementInvalid => e
            Rails.logger.info "Still failed to load fixture #{file}: #{e.message}. Will retry later."
            still_failed << file
          end
        end
        
        failed_fixtures = still_failed
      end
      
      # Report any fixtures that still failed
      if !failed_fixtures.empty?
        Rails.logger.warn "The following fixtures could not be loaded: #{failed_fixtures.join(', ')}"
      end
    end
    
    private
    
    def load_fixture(file)
      table_name = File.basename(file, '.yml')
      fixtures = YAML.load_file(file)
      
      model_class = table_name.classify.constantize
      
      fixtures.each do |label, attributes|
        model_class.create!(attributes)
      end
      
      Rails.logger.info "Loaded fixture #{file}"
    end
  end
end
