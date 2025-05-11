# frozen_string_literal: true

module FixtureSeed
  class Railtie < Rails::Railtie
    rake_tasks do
      # Hook into the existing db:seed task
      Rake::Task["db:seed"].enhance do
        FixtureSeed.load_fixtures
      end
    end
  end
end
