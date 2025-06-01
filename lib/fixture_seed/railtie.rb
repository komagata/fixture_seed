# frozen_string_literal: true

require_relative "loader"

module FixtureSeed
  class Railtie < Rails::Railtie
    rake_tasks do
      namespace :fixture_seed do
        desc "Load fixtures from specified directory"
        task load_fixtures: :environment do
          FixtureSeed::Loader.load_fixtures
        end
      end

      Rake::Task["db:seed"].enhance(["fixture_seed:load_fixtures"]) if Rake::Task.task_defined?("db:seed")
    end
  end
end
