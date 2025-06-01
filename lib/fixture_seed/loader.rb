# frozen_string_literal: true

require "active_record/fixtures"

module FixtureSeed
  class Loader
    class << self
      def load_fixtures(fixtures_path = nil)
        fixtures_path ||= ENV["FIXTURES_PATH"] || "db/fixtures"
        fixtures_dir = Rails.root.join(fixtures_path)

        unless Dir.exist?(fixtures_dir)
          logger = Rails.logger || Logger.new($stdout)
          logger.info "[FixtureSeed] Fixtures directory not found: #{fixtures_path}"
          return
        end

        logger = Rails.logger || Logger.new($stdout)
        logger.info "[FixtureSeed] Loading fixtures from #{fixtures_path}"

        ActiveRecord::Base.transaction do
          with_foreign_keys_disabled do
            load_fixture_files(fixtures_dir, logger)
          end
        end

        logger.info "[FixtureSeed] Finished loading fixtures"
      end

      private

      def load_fixture_files(fixtures_dir, logger)
        fixture_files = Dir.glob("#{fixtures_dir}/*.yml")
        return if fixture_files.empty?

        table_names = fixture_files.map { |f| File.basename(f, ".yml") }
        logger.info "[FixtureSeed] Found tables: #{table_names.join(', ')}"

        ordered_tables = dependency_ordered_tables(table_names)

        ordered_tables.each do |table_name|
          ActiveRecord::FixtureSet.create_fixtures(fixtures_dir.to_s, [table_name])
        end
      end

      def dependency_ordered_tables(table_names)
        ordered = []
        ordered << "users" if table_names.include?("users")
        ordered += (table_names - ["users"])
        ordered
      end

      def with_foreign_keys_disabled
        adapter_name = ActiveRecord::Base.connection.adapter_name.downcase

        disable_foreign_keys(adapter_name)
        yield
      ensure
        enable_foreign_keys(adapter_name)
      end

      def disable_foreign_keys(adapter_name)
        case adapter_name
        when /postgresql/
          ActiveRecord::Base.connection.execute("SET session_replication_role = replica;")
        when /sqlite/
          ActiveRecord::Base.connection.execute("PRAGMA foreign_keys = OFF;")
        when /mysql/
          ActiveRecord::Base.connection.execute("SET FOREIGN_KEY_CHECKS = 0;")
        end
      end

      def enable_foreign_keys(adapter_name)
        case adapter_name
        when /postgresql/
          ActiveRecord::Base.connection.execute("SET session_replication_role = DEFAULT;")
        when /sqlite/
          ActiveRecord::Base.connection.execute("PRAGMA foreign_keys = ON;")
        when /mysql/
          ActiveRecord::Base.connection.execute("SET FOREIGN_KEY_CHECKS = 1;")
        end
      end
    end
  end
end
