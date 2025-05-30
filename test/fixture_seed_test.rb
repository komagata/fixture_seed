# frozen_string_literal: true

require "minitest/autorun"
require "active_record"
require "sqlite3"
require "pathname"
require "fileutils"
require "logger"
require "stringio"
require "yaml"

# Load fixture_seed library
require_relative "../lib/fixture_seed"

# Fixture directory path for testing
FIXTURE_DIR = File.expand_path("dummy/db/fixtures", __dir__)

# Rails stubs
module Rails
  def self.root
    Pathname.new(File.expand_path("dummy", __dir__))
  end

  def self.logger
    @logger ||= Logger.new($stdout)
  end
end

# In-memory database
ActiveRecord::Base.establish_connection(
  adapter: "sqlite3",
  database: ":memory:"
)

# Schema definition
ActiveRecord::Schema.define do
  create_table :users do |t|
    t.string :name, null: false
    t.string :email, null: false
    t.timestamps
  end

  create_table :posts do |t|
    t.string :title, null: false
    t.text :content
    t.integer :user_id, null: false
    t.timestamps
    t.index [:user_id], name: "index_posts_on_user_id"
  end

  create_table :comments do |t|
    t.text :body, null: false
    t.integer :post_id, null: false
    t.timestamps
    t.index [:post_id], name: "index_comments_on_post_id"
  end

  add_foreign_key :posts, :users
  add_foreign_key :comments, :posts
end

# Model definitions
class User < ActiveRecord::Base
  has_many :posts, dependent: :destroy
end

class Post < ActiveRecord::Base
  belongs_to :user
  has_many :comments, dependent: :destroy
end

class Comment < ActiveRecord::Base
  belongs_to :post
end

class FixtureSeedTest < Minitest::Test
  def setup
    # Clear tables in correct order for foreign key constraints
    Comment.delete_all
    Post.delete_all
    User.delete_all

    # Create fixture directory
    FileUtils.rm_rf(FIXTURE_DIR)
    FileUtils.mkdir_p(FIXTURE_DIR)
  end

  def test_normal_order_fixtures
    # Create fixtures in natural dependency order
    File.write(File.join(FIXTURE_DIR, "users.yml"), <<~YAML)
      user1:
        id: 1
        name: Test User
        email: test@example.com
    YAML

    File.write(File.join(FIXTURE_DIR, "posts.yml"), <<~YAML)
      post1:
        id: 1
        title: Test Post
        content: This is a test post
        user_id: 1
    YAML

    File.write(File.join(FIXTURE_DIR, "comments.yml"), <<~YAML)
      comment1:
        id: 1
        body: This is a test comment
        post_id: 1
    YAML

    FixtureSeed.load_fixtures

    # Verify data was loaded correctly
    assert_equal 1, User.count
    assert_equal 1, Post.count
    assert_equal 1, Comment.count

    # Verify associations
    user = User.first
    post = Post.first
    comment = Comment.first

    assert_equal "Test User", user.name
    assert_equal "Test Post", post.title
    assert_equal "This is a test comment", comment.body
    assert_equal user.id, post.user_id
    assert_equal post.id, comment.post_id
  end

  def test_reversed_order_fixtures
    # Create fixtures in reverse dependency order
    File.write(File.join(FIXTURE_DIR, "comments.yml"), <<~YAML)
      comment1:
        id: 1
        body: This is a test comment
        post_id: 1
    YAML

    File.write(File.join(FIXTURE_DIR, "posts.yml"), <<~YAML)
      post1:
        id: 1
        title: Test Post
        content: This is a test post
        user_id: 1
    YAML

    File.write(File.join(FIXTURE_DIR, "users.yml"), <<~YAML)
      user1:
        id: 1
        name: Test User
        email: test@example.com
    YAML

    # Load fixtures with retry logic
    FixtureSeed.load_fixtures

    # Verify data was loaded correctly
    assert_equal 1, User.count, "User record not created"
    assert_equal 1, Post.count, "Post record not created"
    assert_equal 1, Comment.count, "Comment record not created"

    # Verify associations
    user = User.first
    post = Post.first
    comment = Comment.first

    assert_equal "Test User", user.name
    assert_equal "Test Post", post.title
    assert_equal "This is a test comment", comment.body
    assert_equal user.id, post.user_id
    assert_equal post.id, comment.post_id
  end
end
