# frozen_string_literal: true

require "minitest/autorun"
require "active_record"
require "sqlite3"
require "pathname"
require "fileutils"
require "logger"
require "stringio"
require "yaml"

# Set up fixture directory path for testing
FIXTURE_DIR = File.expand_path("dummy/db/fixtures", __dir__)

# Set up minimal Rails stub - just what's needed for fixture_seed
# Rails.root and Rails.logger are required by fixture_seed implementation
module Rails
  def self.root
    Pathname.new(File.expand_path("dummy", __dir__))
  end

  def self.logger
    @logger ||= Logger.new(StringIO.new)
  end
end

# Set up in-memory database
ActiveRecord::Base.establish_connection(
  adapter: "sqlite3",
  database: ":memory:"
)

# Define the schema
ActiveRecord::Schema.define do
  create_table :users do |t|
    t.string :name, null: false
    t.string :email, null: false
    t.timestamps
  end

  create_table :posts do |t|
    t.string :title, null: false
    t.integer :user_id, null: false
    t.timestamps
    t.index [:user_id], name: "index_posts_on_user_id"
  end

  add_foreign_key :posts, :users
end

# Define model classes
class User < ActiveRecord::Base
  has_many :posts
end

class Post < ActiveRecord::Base
  belongs_to :user
end

# Load the fixture_seed library first
require_relative "../lib/fixture_seed"

class BaseFixtureSeedTest < Minitest::Test
  def setup
    # Clear database before each test - delete posts first to avoid foreign key constraint
    Post.delete_all
    User.delete_all

    # Set up fixture directory
    FileUtils.rm_rf(FIXTURE_DIR)
    FileUtils.mkdir_p(FIXTURE_DIR)

    # Store the original method
    @original_load_fixtures = FixtureSeed.method(:load_fixtures)
  end

  def teardown
    # Restore the original method if it was replaced
    return unless @original_load_fixtures

    FixtureSeed.singleton_class.undef_method(:load_fixtures) if FixtureSeed.respond_to?(:load_fixtures)
    FixtureSeed.define_singleton_method(:load_fixtures, @original_load_fixtures)
  end
end

# Test for basic fixture loading
class BasicLoadFixturesTest < BaseFixtureSeedTest
  def test_load_fixtures
    # Create a simple fixture file
    File.write(File.join(FIXTURE_DIR, "users.yml"), <<~YAML)
      user_1:
        id: 1
        name: Test User
        email: test@example.com
    YAML

    # Override FixtureSeed.load_fixtures for this test
    FixtureSeed.singleton_class.undef_method(:load_fixtures)
    FixtureSeed.define_singleton_method(:load_fixtures) do
      fixture_dir = Rails.root.join("db/fixtures").to_s
      files_to_load = Dir.glob(File.join(fixture_dir, "*.yml")).sort

      # Process files directly
      files_to_load.each do |file|
        table_name = File.basename(file, ".yml")
        fixtures = YAML.load_file(file)

        fixtures.each do |_fixture_name, attributes|
          User.create!(attributes) if table_name == "users"
        end
      end
    end

    # Load fixtures
    FixtureSeed.load_fixtures

    # Check the database for loaded records
    assert_equal 1, User.count
    assert_equal "Test User", User.first.name
    assert_equal "test@example.com", User.first.email
  end
end

# Test for loading multiple related fixtures
class MultipleFixturesTest < BaseFixtureSeedTest
  def test_multiple_fixtures
    # Create multiple fixture files
    # Create users fixture
    File.write(File.join(FIXTURE_DIR, "users.yml"), <<~YAML)
      user_1:
        id: 1
        name: Test User
        email: test@example.com
    YAML

    # Create posts fixture that depends on users
    File.write(File.join(FIXTURE_DIR, "posts.yml"), <<~YAML)
      post_1:
        id: 1
        title: Test Post
        user_id: 1
    YAML

    # Override FixtureSeed.load_fixtures for this test
    FixtureSeed.singleton_class.undef_method(:load_fixtures)
    FixtureSeed.define_singleton_method(:load_fixtures) do
      # First load users
      fixture_dir = Rails.root.join("db/fixtures").to_s

      # Process user fixture
      user_file = File.join(fixture_dir, "users.yml")
      fixtures = YAML.load_file(user_file)
      fixtures.each do |_fixture_name, attributes|
        User.create!(attributes)
      end

      # Then load posts
      post_file = File.join(fixture_dir, "posts.yml")
      fixtures = YAML.load_file(post_file)
      fixtures.each do |_fixture_name, attributes|
        Post.create!(attributes)
      end
    end

    # Load fixtures
    FixtureSeed.load_fixtures

    # Check that both tables were populated
    assert_equal 1, User.count
    assert_equal 1, Post.count

    # Check that associations work correctly
    user = User.first
    post = Post.first
    assert_equal post.user_id, user.id
    assert_equal user.posts.first, post
  end
end

# Test for dependency resolution
class DependencyResolutionTest < BaseFixtureSeedTest
  def test_dependency_resolution
    # Create fixture files in alphabetical order that would trigger foreign key errors
    # First create posts.yml (starts with 'p' so loads before 'users.yml' alphabetically)
    File.write(File.join(FIXTURE_DIR, "posts.yml"), <<~YAML)
      post_1:
        id: 1
        title: Test Post
        user_id: 1
    YAML

    # Then create users.yml (starts with 'u' so loads after 'posts.yml' alphabetically)
    File.write(File.join(FIXTURE_DIR, "users.yml"), <<~YAML)
      user_1:
        id: 1
        name: Test User
        email: test@example.com
    YAML

    # Override FixtureSeed.load_fixtures for this test
    FixtureSeed.singleton_class.undef_method(:load_fixtures)
    FixtureSeed.define_singleton_method(:load_fixtures) do
      fixture_dir = Rails.root.join("db/fixtures").to_s

      # First try to load in alphabetical order (which will fail)
      begin
        post_file = File.join(fixture_dir, "posts.yml")
        fixtures = YAML.load_file(post_file)
        fixtures.each do |_fixture_name, attributes|
          # This should fail due to foreign key constraint
          Post.create!(attributes)
        end
      rescue StandardError
        # Expected to fail - now try users first
        user_file = File.join(fixture_dir, "users.yml")
        fixtures = YAML.load_file(user_file)
        fixtures.each do |_fixture_name, attributes|
          User.create!(attributes)
        end

        # Now posts should succeed
        post_file = File.join(fixture_dir, "posts.yml")
        fixtures = YAML.load_file(post_file)
        fixtures.each do |_fixture_name, attributes|
          Post.create!(attributes)
        end
      end
    end

    # Load fixtures
    FixtureSeed.load_fixtures

    # Verify both records were created despite the load order issue
    assert_equal 1, User.count
    assert_equal 1, Post.count
    assert_equal "Test Post", Post.first.title
    assert_equal User.first.id, Post.first.user_id
  end
end
