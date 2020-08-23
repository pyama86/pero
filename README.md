# Pero

It is puppet run tool on local OS.
## Installation

Add this line to your application's Gemfile:

```ruby
gem 'pero'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install pero

## Depends

- Docker

## Usage

### Install puppet

```
$ pero install --agent-version 3.3.1 10.0.0.1 # hostname is example.com
```

### Apply puppet

```
$ pero apply --server -version 3.3.1 example.com
```

### Show Support version

```
$ pero versions
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/pero.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
