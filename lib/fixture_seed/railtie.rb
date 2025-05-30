# frozen_string_literal: true

module FixtureSeed
  class Railtie < Rails::Railtie
    initializer "fixture_seed.initialize" do
      Rails.logger.info "[FixtureSeed] Railtie initialized"
    end

    rake_tasks do
      if Rake::Task.task_defined?("db:seed")
        Rake::Task["db:seed"].enhance do
          Rails.logger.info "[FixtureSeed] Starting to load fixtures through db:seed enhancement"
          FixtureSeed.load_fixtures
          Rails.logger.info "[FixtureSeed] Finished loading fixtures"
        end
      else
        Rails.logger.warn "[FixtureSeed] db:seed task not found, fixture loading enhancement not applied"
      end
    end
  end
end
