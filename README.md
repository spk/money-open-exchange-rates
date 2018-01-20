# Money Open Exchange Rates

A gem that calculates the exchange rate using published rates from
[open-exchange-rates](https://openexchangerates.org/)

Check [api documentation](https://docs.openexchangerates.org/)

* [Live](https://docs.openexchangerates.org/docs/latest-json) and
    [historical](https://docs.openexchangerates.org/docs/historical-json)
    exchange rates for
    [180 currencies](https://docs.openexchangerates.org/docs/supported-currencies).
* [Free plan](https://openexchangerates.org/signup) hourly updates, with USD
    base and up to 1,000 requests/month.
* Currency caching.
* Calculate pair rates.

## Installation

Add this line to your application's Gemfile:

~~~ ruby
gem 'money-open-exchange-rates'
~~~

And then execute:

~~~
bundle
~~~

Or install it yourself as:

~~~
gem install money-open-exchange-rates
~~~

## Usage

~~~ ruby
require 'money/bank/open_exchange_rates_bank'
oxr = Money::Bank::OpenExchangeRatesBank.new
oxr.cache = 'path/to/file/cache.json'
oxr.app_id = 'your app id from https://openexchangerates.org/signup'
oxr.update_rates

# (optional)
# set the seconds after than the current rates are automatically expired
# by default, they never expire, in this example 1 day.
oxr.ttl_in_seconds = 86400
# (optional)
# use https to fetch rates from Open Exchange Rates
# disabled by default to support free-tier users
# see https://openexchangerates.org/documentation#https
oxr.secure_connection = true
# (optional)
# set historical date of the rate
# see https://openexchangerates.org/documentation#historical-data
oxr.date = '2015-01-01'
# (optional)
# Set the base currency for all rates. By default, USD is used.
# OpenExchangeRates only allows USD as base currency
# for the free plan users.
oxr.source = 'USD'

# Store in cache
# If you are using unicorn-worker-killer gem or on Heroku like platform,
# you should avoid to put this on the initializer of your Rails application,
# because will increase your OXR API usage.
oxr.save_rates

Money.default_bank = oxr

Money.default_bank.get_rate('USD', 'CAD')
~~~

You can also provide a Proc as a cache to provide your own caching mechanism
perhaps with Redis or just a thread safe `Hash` (global). For example:

~~~ ruby
oxr.cache = Proc.new do |v|
  key = 'money:exchange_rates'
  if v
    Thread.current[key] = v
  else
    Thread.current[key]
  end
end
~~~

Unknown pair rates are transparently calculated: using inverse rate (if known),
or using base currency rate to both currencies forming the pair.

## Tests

~~~
bundle exec rake
~~~

## Refs

* <https://github.com/josscrowcroft/open-exchange-rates>
* <https://github.com/RubyMoney/money>
* <https://github.com/RubyMoney/eu_central_bank>
* <https://github.com/RubyMoney/google_currency>

## Contributors

See [GitHub](https://github.com/spk/money-open-exchange-rates/graphs/contributors).

## License

The MIT License

Copyright © 2011-2018 Laurent Arnoud <laurent@spkdev.net>

---
[![Build](https://img.shields.io/travis-ci/spk/money-open-exchange-rates.svg)](https://travis-ci.org/spk/money-open-exchange-rates)
[![Version](https://img.shields.io/gem/v/money-open-exchange-rates.svg)](https://rubygems.org/gems/money-open-exchange-rates)
[![Documentation](https://img.shields.io/badge/doc-rubydoc-blue.svg)](http://www.rubydoc.info/gems/money-open-exchange-rates)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](http://opensource.org/licenses/MIT "MIT")
[![Code Climate](https://img.shields.io/codeclimate/github/spk/money-open-exchange-rates.svg)](https://codeclimate.com/github/spk/money-open-exchange-rates)
[![Inline docs](https://inch-ci.org/github/spk/money-open-exchange-rates.svg?branch=master)](http://inch-ci.org/github/spk/money-open-exchange-rates)
