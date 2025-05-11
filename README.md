# FixtureSeed

FixtureSeed is a Rails gem that automatically loads YAML fixture files from the `db/fixtures/` directory when running `rails db:seed`. It loads the fixtures in alphabetical order and handles foreign key constraint errors by retrying failed inserts after all other fixtures are loaded.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'fixture_seed'
```

And then execute:

```bash
$ bundle install
```

## Usage

Once the gem is installed, it will automatically hook into Rails' `db:seed` task. You don't need to modify your `seeds.rb` file.

### Directory Structure

Place your YAML fixture files in the `db/fixtures/` directory:

```
db/
  fixtures/
    posts.yml
    users.yml
```

### Fixture Format

The fixture files should be named after the table they correspond to (e.g., `users.yml` for the `users` table).

The content of the fixture files should follow this format:

```yaml
# users.yml
user1:
  id: 1
  name: "John Doe"
  email: "john@example.com"

user2:
  id: 2
  name: "Jane Smith"
  email: "jane@example.com"
```

The labels (e.g., `user1`, `user2`) should follow the pattern of the table name in singular form followed by a number.

### Loading Order

Fixtures are loaded in alphabetical order by filename. However, if a fixture fails to load due to foreign key constraints, it will be retried after all other fixtures have been processed.

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/komagata/fixture_seed.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
