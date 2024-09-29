# Vitess::Activerecord::Migration

vitess-activerecord-migration is a gem for integrating Vitess with ActiveRecord migrations.

Vitess::Activerecord::Migration provides tools to integrate Vitess with ActiveRecord migrations, 
allowing for seamless database schema changes in a Vitess environment.

## Installation

```
gem 'vitess-activerecord-migration'
```

## Usage

Add a file including the following line under config/initializers.

```ruby
ActiveRecord::Migration.prepend(Vitess::Activerecord::Migration)
```

## Development

After checking out the repo, run the following command to start related containers.

```bash
$ docker compose up
```

Then, you can run the following command to create a vitess cluster.

```bash
$ docker exec -it migration-endtoend /bin/bash
323e040cee42:/endtoend# make migration-test-setup
```

Finally, you can run the test suite to verify that the gem works correctly.

```bash
$ docker exec -it migration /bin/bash
root@0401705ea521:/migration# rake spec
```

To install this gem onto your local machine, run `bundle exec rake install`.
To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`,
which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/yoheimuta/vitess-activerecord-migration.
This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/[USERNAME]/vitess-activerecord-migration/blob/main/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the Vitess::Activerecord::Migration project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/[USERNAME]/vitess-activerecord-migration/blob/main/CODE_OF_CONDUCT.md).
