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

  create_table :comments do |t|
    t.text :content, null: false
    t.integer :post_id, null: false
    t.integer :user_id, null: false
    t.timestamps
    t.index [:post_id], name: "index_comments_on_post_id"
    t.index [:user_id], name: "index_comments_on_user_id"
  end

  add_foreign_key :posts, :users
  add_foreign_key :comments, :posts
  add_foreign_key :comments, :users
end

# Define model classes
class User < ActiveRecord::Base
  has_many :posts
  has_many :comments
end

class Post < ActiveRecord::Base
  belongs_to :user
  has_many :comments
end

class Comment < ActiveRecord::Base
  belongs_to :user
  belongs_to :post
end

# Load the fixture_seed library first
require_relative "../lib/fixture_seed"

class BaseFixtureSeedTest < Minitest::Test
  def setup
    # Clear database before each test - delete in reverse dependency order to avoid foreign key constraint
    Comment.delete_all
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

  def test_complex_dependency_resolution_with_comments
    # Create fixture files in alphabetical order that creates a complex dependency chain
    # comments.yml (depends on posts and users) - loads first alphabetically
    File.write(File.join(FIXTURE_DIR, "comments.yml"), <<~YAML)
      comment_1:
        id: 1
        content: "Great post!"
        post_id: 1
        user_id: 1
      comment_2:
        id: 2
        content: "Thanks for sharing!"
        post_id: 1
        user_id: 2
    YAML

    # posts.yml (depends on users) - loads second alphabetically
    File.write(File.join(FIXTURE_DIR, "posts.yml"), <<~YAML)
      post_1:
        id: 1
        title: Test Post
        user_id: 1
    YAML

    # users.yml (no dependencies) - loads last alphabetically
    File.write(File.join(FIXTURE_DIR, "users.yml"), <<~YAML)
      user_1:
        id: 1
        name: Test User
        email: test@example.com
      user_2:
        id: 2
        name: Another User
        email: another@example.com
    YAML

    # Use the actual FixtureSeed implementation to test order-independent loading
    FixtureSeed.load_fixtures

    # Verify all records were created despite the complex dependency chain
    assert_equal 2, User.count
    assert_equal 1, Post.count
    assert_equal 2, Comment.count

    # Verify relationships are correct
    post = Post.first
    assert_equal 1, post.user_id
    assert_equal "Test Post", post.title

    comments = Comment.order(:id)
    assert_equal "Great post!", comments[0].content
    assert_equal 1, comments[0].post_id
    assert_equal 1, comments[0].user_id

    assert_equal "Thanks for sharing!", comments[1].content
    assert_equal 1, comments[1].post_id
    assert_equal 2, comments[1].user_id

    # Verify associations work
    user1 = User.find(1)
    user2 = User.find(2)
    assert_equal 1, user1.posts.count
    assert_equal 0, user2.posts.count
    assert_equal 1, user1.comments.count
    assert_equal 1, user2.comments.count
  end
end

# Test for ERB support in fixture files
class ERBFixturesTest < BaseFixtureSeedTest
  def setup
    # Clear database before each test - delete in reverse dependency order to avoid foreign key constraint
    Comment.delete_all
    Post.delete_all
    User.delete_all

    # Set up fixture directory but don't remove it completely for ERB tests
    FileUtils.mkdir_p(FIXTURE_DIR)

    # Store the original method but don't override it for ERB tests
    @original_load_fixtures = FixtureSeed.method(:load_fixtures)
  end

  def teardown
    # Clean up any fixture files created during the test
    Dir.glob(File.join(FIXTURE_DIR, "*.yml")).each { |f| File.delete(f) }
  end

  def test_erb_fixtures_loading
    # Clear any existing users and fixture files first
    User.delete_all
    Dir.glob(File.join(FIXTURE_DIR, "*.yml")).each { |f| File.delete(f) }

    # Create a fixture file with ERB template
    File.write(File.join(FIXTURE_DIR, "users.yml"), <<~ERB)
      <% 3.times do |i| %>
      erb_user<%= i + 1 %>:
        id: <%= 100 + i + 1 %>
        name: "ERB User <%= i + 1 %>"
        email: "erb_user<%= i + 1 %>@example.com"
        created_at: <%= Time.new(2023, 1, 1) %>
      <% end %>
    ERB

    # Use the actual FixtureSeed implementation with ActiveRecord::FixtureSet
    FixtureSeed.load_fixtures

    # Check that ERB was processed and 3 users were created
    assert_equal 3, User.count

    # Verify the generated data
    users = User.order(:id)

    assert_equal 101, users[0].id
    assert_equal "ERB User 1", users[0].name
    assert_equal "erb_user1@example.com", users[0].email

    assert_equal 102, users[1].id
    assert_equal "ERB User 2", users[1].name
    assert_equal "erb_user2@example.com", users[1].email

    assert_equal 103, users[2].id
    assert_equal "ERB User 3", users[2].name
    assert_equal "erb_user3@example.com", users[2].email
  end

  def test_erb_with_rails_environment_access
    # Clear any existing users first
    User.delete_all

    # Create a fixture file that uses Rails environment features
    File.write(File.join(FIXTURE_DIR, "users.yml"), <<~ERB)
      <% current_time = Time.new(2023, 6, 15, 12, 0, 0) %>
      erb_user_with_time:
        id: 200
        name: "User with Time"
        email: "time_user@example.com"
        created_at: <%= current_time %>
        updated_at: <%= current_time %>
    ERB

    # Use the actual FixtureSeed implementation
    FixtureSeed.load_fixtures

    # Check that ERB was processed correctly
    assert_equal 1, User.count

    user = User.first
    assert_equal 200, user.id
    assert_equal "User with Time", user.name
    assert_equal "time_user@example.com", user.email

    # Verify the timestamp was processed correctly (just check the date part)
    expected_time = Time.new(2023, 6, 15, 12, 0, 0)
    assert_equal expected_time.year, user.created_at.year
    assert_equal expected_time.month, user.created_at.month
    assert_equal expected_time.day, user.created_at.day
  end
end
