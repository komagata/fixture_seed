# frozen_string_literal: true

require_relative "test_helper"

class FixtureSeedTest < Minitest::Test
  include TestHelper

  def test_fixture_loading_without_constraints
    fixture_dir = create_fixture_dir

    File.write(File.join(fixture_dir, "users.yml"), <<~YAML)
      user_1:
        id: 1
        name: "Test User 1"
        email: "user1@example.com"

      user_2:
        id: 2
        name: "Test User 2"
        email: "user2@example.com"
    YAML

    File.write(File.join(fixture_dir, "tools.yml"), <<~YAML)
      tool_1:
        name: "Hammer"
        description: "Useful tool"
        user_id: 1

      tool_2:
        name: "Screwdriver"
        description: "Another useful tool"
        user_id: 2
    YAML

    FixtureSeed.load_fixtures(fixture_dir)

    assert_equal 2, User.count
    assert_equal 2, Tool.count
    assert_equal "Test User 1", User.find_by(email: "user1@example.com").name
    assert_equal "Test User 2", User.find_by(email: "user2@example.com").name

    hammer = Tool.find_by(name: "Hammer")
    screwdriver = Tool.find_by(name: "Screwdriver")
    assert_equal "Test User 1", hammer.user.name
    assert_equal "Test User 2", screwdriver.user.name
  ensure
    cleanup_fixture_dir(fixture_dir) if fixture_dir
  end

  def test_fixture_loading_with_foreign_key_constraints
    fixture_dir = create_fixture_dir

    File.write(File.join(fixture_dir, "comments.yml"), <<~YAML)
      comment_1:
        content: "First comment"
        user_id: 1

      comment_2:
        content: "Second comment"
        user_id: 2
    YAML

    File.write(File.join(fixture_dir, "users.yml"), <<~YAML)
      user_1:
        id: 1
        name: "Test User 1"
        email: "user1@example.com"

      user_2:
        id: 2
        name: "Test User 2"
        email: "user2@example.com"
    YAML

    FixtureSeed.load_fixtures(fixture_dir)

    assert_equal 2, User.count
    assert_equal 2, Comment.count

    user1 = User.find(1)
    user2 = User.find(2)
    comment1 = Comment.find_by(content: "First comment")
    comment2 = Comment.find_by(content: "Second comment")

    assert_equal user1, comment1.user
    assert_equal user2, comment2.user
    assert_equal "Test User 1", comment1.user.name
    assert_equal "Test User 2", comment2.user.name
  ensure
    cleanup_fixture_dir(fixture_dir) if fixture_dir
  end

  def test_foreign_key_constraint_behavior
    adapter_name = ActiveRecord::Base.connection.adapter_name.downcase

    skip "Not SQLite" unless adapter_name.include?("sqlite")

    fixture_dir = create_fixture_dir

    begin
      File.write(File.join(fixture_dir, "comments.yml"), <<~YAML)
        comment_1:
          content: "Comment with non-existent user"
          user_id: 999
      YAML

      File.write(File.join(fixture_dir, "users.yml"), <<~YAML)
        user_1:
          id: 999
          name: "User created after comment"
          email: "late@example.com"
      YAML

      FixtureSeed.load_fixtures(fixture_dir)

      assert_equal 1, User.count
      assert_equal 1, Comment.count
      assert_equal 999, Comment.first.user_id
      assert_equal 999, User.first.id
    ensure
      cleanup_fixture_dir(fixture_dir) if fixture_dir
    end
  end
end
