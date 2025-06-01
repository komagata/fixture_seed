# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

require "fixture_seed"
require "rails"
require "active_record"
require "minitest/autorun"
require "logger"
require "fileutils"
require "tmpdir"
require "securerandom"

class TestApplication < Rails::Application
  config.eager_load = false
  config.logger = Logger.new($stdout)
  config.log_level = :info
  config.root = File.expand_path("..", __dir__)
end

unless Rails.application
  Rails.application = TestApplication.new
  Rails.application.initialize!
end

ActiveRecord::Base.establish_connection(
  adapter: "sqlite3",
  database: ":memory:"
)

ActiveRecord::Schema.define do
  create_table :users, force: true do |t|
    t.string :name, null: false
    t.string :email, null: false
  end

  create_table :comments, force: true do |t|
    t.text :content, null: false
    t.references :user, null: false, foreign_key: true
  end

  create_table :tools, force: true do |t|
    t.string :name, null: false
    t.text :description
    t.references :user, null: false, foreign_key: true
  end
end

class User < ActiveRecord::Base
  has_many :comments
  has_many :tools
end

class Comment < ActiveRecord::Base
  belongs_to :user
end

class Tool < ActiveRecord::Base
  belongs_to :user
end

module TestHelper
  def setup
    clear_database
  end

  def teardown
    clear_database
    reset_activerecord_state
  end

  def create_fixture_dir
    fixture_dir = File.join(Dir.tmpdir, "fixture_seed_test_#{SecureRandom.hex(4)}")
    FileUtils.mkdir_p(fixture_dir)
    fixture_dir
  end

  def cleanup_fixture_dir(fixture_dir)
    FileUtils.rm_rf(fixture_dir)
  end

  private

  def clear_database
    Tool.delete_all
    Comment.delete_all
    User.delete_all
  end

  def reset_activerecord_state
    ActiveRecord::FixtureSet.reset_cache
    ActiveRecord::Base.connection.schema_cache.clear!
  end
end
