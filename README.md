# danger-pyright

Find type checking issues in Python files using [Pyright](https://github.com/microsoft/pyright).

## Installation

### Via global gems

```
$ gem install danger-pyright
```

### Via Bundler

Add the following line to your Gemfile and then run `bundle install`:

```rb
gem 'danger-pyright'
```

## Usage

### Basic

Check for type checking issues running the script from current directory. Prints a markdown table with all issues found:

```rb
pyright.lint
```

### Advanced

#### Running from a custom directory

Changes root folder from where pyright is running:

```rb
pyright.base_dir = "src"
pyright.lint
```

#### Use GitHub's inline comments instead of a markdown table

```rb
pyright.lint(use_inline_comments=true)
```

#### Running using a configuration file different than the usual

If you need to specify a different configuration file, use the `config_file` parameter below. Check [Pyright documentation](https://github.com/microsoft/pyright/blob/main/docs/configuration.md) for more information about configuration files.

```rb
pyright.config_file = "pyrightconfig.json"
pyright.lint
```

#### Printing a warning message with number of errors

Adds an entry onto the warnings/failures table:

```rb
pyright.count_errors
```

#### Defining a threshold of max errors

Warns if number of issues is greater than a given threshold:

```rb
pyright.threshold = 10
pyright.count_errors
```

Fails if number of issues is greater than a given threshold:

```rb
pyright.threshold = 10
pyright.count_errors(should_fail = true)
```

## Development

1. Clone this repo
2. Run `bundle install` to setup dependencies.
3. Run `bundle exec rake spec` to run the tests.
4. Use `bundle exec guard` to automatically have tests run as you make changes.
5. Make your changes.

## License

MIT

