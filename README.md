# ActiveRecordValueObjects

A simple gem to allow you to store value objects in your ActiveRecord models backed by jsonb columns.

## Motivation

Sometimes you want to store structured data in a jsonb column in your database. This gem allows you to define a value object that can be stored in a jsonb column and provides a simple way to define the schema of the value object.

This lets you store objects without needing to do complex joins or create additional tables.
## Example

```ruby
class Address < ActiveRecordValueObjects::ValueObject
  attribute :street, Types::String
  attribute :city, Types::String
  attribute :state, Types::String
  attribute :zip, Types::String
end

class User < ApplicationRecord
  value_attribute :address, Address 
end
```

Values are immutable by default, but you can easily make copies of them with changes:

```ruby
new_address = Address.new(street: '123 Main St', city: 'Springfield', state: 'IL', zip: '62701')
  .copy_with(city: 'Chicago')
```
## Translating validation errors

Validation errors on a value object are copied onto the record under a path such as
`address/city`, or `addresses/0/city` for an array attribute. They go through Rails I18n,
so you translate them the same way as any other ActiveRecord error. Without translations
you get the usual English messages.

Messages are looked up in this order:

1. The record, keyed by the path: `activerecord.errors.models.user.attributes.address/city.blank`.
   Array elements are looked up by index first (`addresses/0/city`), then without it (`addresses/city`).
2. The value object (`activemodel.errors.models.address.attributes.city.blank`, then
   `activemodel.errors.models.address.blank`).
3. The type: `activemodel.errors.messages.blank`, then `errors.messages.blank`.

```yaml
# config/locales/fr.yml
fr:
  errors:
    messages:
      blank: "doit être rempli(e)"
  activerecord:
    errors:
      models:
        user:
          attributes:
            "address/city":
              blank: "indiquez une ville"
            "addresses/city":
              blank: "chaque adresse a besoin d'une ville"
```

As with Rails' own attributes, a translation keyed to the record (step 1) also replaces a
custom `message:` given to the validator. Steps 2 and 3 never do. Options such as `count`
are passed along, so `%{count}` works in `too_long` and the other length messages.

### gettext

To use gettext, plug it in as the I18n backend with
[gettext_i18n_rails](https://github.com/grosser/gettext_i18n_rails). Its backend serves the
lookups above from your `.po` files. A msgid can be the I18n key, such as
`activerecord.errors.models.user.attributes.address/city.blank`, or the English message
itself, such as `can't be blank`. The English message works because it is passed as the
lookup's default.

```ruby
# Gemfile
gem 'gettext_i18n_rails'

# config/initializers/fast_gettext.rb
FastGettext.add_text_domain 'app', path: 'locale', type: :po
FastGettext.default_available_locales = %w[en fr]
FastGettext.default_text_domain = 'app'
```

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'active_record_value_objects'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install active_record_value_objects

## Usage

TODO: Write usage instructions here

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/active_record_value_objects. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the ActiveRecordValueObjects project’s codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/[USERNAME]/active_record_value_objects/blob/master/CODE_OF_CONDUCT.md).
