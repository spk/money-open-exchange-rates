# Money Open Exchange Rates

A gem that calculates the exchange rate using published rates from
[open-exchange-rates](https://openexchangerates.org/)

## Usage

~~~ ruby
require 'money/bank/open_exchange_rates_bank'
moe = Money::Bank::OpenExchangeRatesBank.new
moe.cache = 'path/to/file/cache'
moe.app_id = 'your app id from https://openexchangerates.org/signup'
moe.update_rates

# (optional)
# set the seconds after than the current rates are automatically expired
# by default, they never expire, in this example 1 day.
moe.ttl_in_seconds = 86400
# (optional)
# use https to fetch rates from Open Exchange Rates
# disabled by default to support free-tier users
# see https://openexchangerates.org/documentation#https
moe.secure_connection = true
# (optional)
# set historical date of the rate
# see https://openexchangerates.org/documentation#historical-data
moe.date = '2015-01-01'
# Store in cache
moe.save_rates

Money.default_bank = moe
~~~

You can also provide a Proc as a cache to provide your own caching mechanism
perhaps with Redis or just a thread safe `Hash` (global). For example:

~~~ ruby
moe.cache = Proc.new do |v|
  key = 'money:exchange_rates'
  if v
    Thread.current[key] = v
  else
    Thread.current[key]
  end
end
~~~

## Tests

~~~
bundle exec rake
~~~

## Refs

* <https://github.com/currencybot/open-exchange-rates>
* <https://github.com/RubyMoney/money>
* <https://github.com/RubyMoney/eu_central_bank>
* <https://github.com/RubyMoney/google_currency>

## Contributors

See [GitHub](https://github.com/spk/money-open-exchange-rates/graphs/contributors).

## License

The MIT License

Copyright © 2011-2016 Laurent Arnoud <laurent@spkdev.net>

---
[![Build](https://img.shields.io/travis-ci/spk/money-open-exchange-rates.svg)](https://travis-ci.org/spk/money-open-exchange-rates)
[![Version](https://img.shields.io/gem/v/money-open-exchange-rates.svg)](https://rubygems.org/gems/money-open-exchange-rates)
[![Documentation](https://img.shields.io/badge/doc-rubydoc-blue.svg)](http://www.rubydoc.info/gems/money-open-exchange-rates)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](http://opensource.org/licenses/MIT "MIT")
[![Code Climate](http://img.shields.io/codeclimate/github/spk/money-open-exchange-rates.svg)](https://codeclimate.com/github/spk/money-open-exchange-rates)
[![Inline docs](http://inch-ci.org/github/spk/money-open-exchange-rates.svg?branch=master)](http://inch-ci.org/github/spk/money-open-exchange-rates)
