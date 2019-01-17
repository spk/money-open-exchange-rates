# Money Open Exchange Rates

A gem that calculates the exchange rate using published rates from
[open-exchange-rates](https://openexchangerates.org/). Compatible with
[Money](https://github.com/RubyMoney/money#currency-exchange) [currency
exchange](http://www.rubydoc.info/gems/money/Money/Bank/VariableExchange).

Check [api documentation](https://docs.openexchangerates.org/)

* [Live](https://docs.openexchangerates.org/docs/latest-json) and
    [historical](https://docs.openexchangerates.org/docs/historical-json)
    exchange rates for
    [180 currencies](https://docs.openexchangerates.org/docs/supported-currencies).
* [Free plan](https://openexchangerates.org/signup) hourly updates, with USD
    base and up to 1,000 requests/month.
* Automatically caches API results to file or Rails cache.
* Calculate pair rates.
* Automatically fetches new data from API if data becomes stale when
    `ttl_in_seconds` option is provided.
* Support for black market and digital currency rates with `show_alternative`
    option.

## Installation

Add this line to your application's Gemfile:

``` ruby
gem 'money-open-exchange-rates'
```

And then execute:

~~~
bundle
~~~

Or install it yourself as:

~~~
gem install money-open-exchange-rates
~~~

## Usage

``` ruby
require 'money/bank/open_exchange_rates_bank'

# Memory store per default; for others just pass as argument a class like
# explained in https://github.com/RubyMoney/money#exchange-rate-stores
oxr = Money::Bank::OpenExchangeRatesBank.new
oxr.app_id = 'your app id from https://openexchangerates.org/signup'
oxr.update_rates

# (optional)
# See https://github.com/spk/money-open-exchange-rates#cache for more info
# Updated only when `refresh_rates` is called
oxr.cache = 'path/to/file/cache.json'

# (optional)
# Set the seconds after than the current rates are automatically expired
# by default, they never expire, in this example 1 day.
# This ttl is about money store (memory, database ...) passed though
# `Money::Bank::OpenExchangeRatesBank` as argument not about `cache` option.
# The base time is the timestamp fetched from API.
oxr.ttl_in_seconds = 86400

# (optional)
# Set historical date of the rate
# see https://openexchangerates.org/documentation#historical-data
oxr.date = '2015-01-01'

# (optional)
# Set the base currency for all rates. By default, USD is used.
# OpenExchangeRates only allows USD as base currency
# for the free plan users.
oxr.source = 'USD'

# (optional)
# Extend returned values with alternative, black market and digital currency
# rates. By default, false is used
# see: https://docs.openexchangerates.org/docs/alternative-currencies
oxr.show_alternative = true

# (optional)
# Minified Response ('prettyprint')
# see https://docs.openexchangerates.org/docs/prettyprint
oxr.prettyprint = false

# (optional)
# Refresh rates, store in cache and update rates
# Should be used on crontab/worker/scheduler `Money.default_bank.refresh_rates`
# If you are using unicorn-worker-killer gem or on Heroku like platform,
# you should avoid to put this on the initializer of your Rails application,
# because will increase your OXR API usage.
oxr.refresh_rates

# (optional)
# Force refresh rates cache and store on the fly when ttl is expired
# This will slow down request on get_rate, so use at your on risk, if you don't
# want to setup crontab/worker/scheduler for your application
oxr.force_refresh_rate_on_expire = true

Money.default_bank = oxr

Money.default_bank.get_rate('USD', 'CAD')
```

## Cache

You can also provide a `Proc` as a cache to provide your own caching mechanism
perhaps with Redis or just a thread safe `Hash` (global). For example:

``` ruby
oxr.cache = Proc.new do |v|
  key = 'money:exchange_rates'
  if v
    Thread.current[key] = v
  else
    Thread.current[key]
  end
end
```

With `Rails` cache example:

``` ruby
OXR_CACHE_KEY = "#{Rails.env}:money:exchange_rates".freeze
oxr.ttl_in_seconds = 86400
oxr.cache = Proc.new do |text|
  if text
    Rails.cache.write(OXR_CACHE_KEY, text)
  else
    Rails.cache.read(OXR_CACHE_KEY)
  end
end
```

To update the cache call `Money.default_bank.refresh_rates` on
crontab/worker/scheduler. This have to be done this way because the fetch can
take some time (HTTP call) and can fail.

## Full example configuration initializer with Rails and cache

``` ruby
require 'money/bank/open_exchange_rates_bank'

OXR_CACHE_KEY = "#{Rails.env}:money:exchange_rates".freeze
# ExchangeRate is an ActiveRecord model
# more info at https://github.com/RubyMoney/money#exchange-rate-stores
oxr = Money::Bank::OpenExchangeRatesBank.new(ExchangeRate)
oxr.ttl_in_seconds = 86400
oxr.cache = Proc.new do |text|
  if text
    # only expire when refresh_rates is called or `force_refresh_rate_on_expire`
    # option is enabled
    # you can also set `expires_in` option on write to force fetch new rates
    Rails.cache.write(OXR_CACHE_KEY, text)
  else
    Rails.cache.read(OXR_CACHE_KEY)
  end
end
oxr.app_id = ENV['OXR_API_KEY']
oxr.show_alternative = true
oxr.prettyprint = false
oxr.update_rates

Money.default_bank = oxr
```

### Tests

To avoid to hit the API we can use the cache option with a saved file like this:

``` ruby
OXR_CACHE_KEY = "#{Rails.env}:money:exchange_rates".freeze
if Rails.env.test?
  oxr.cache = Rails.root.join("test/fixtures/currency-rates.json").to_s
else
  oxr.ttl_in_seconds = 5.minutes.to_i
  oxr.cache = Proc.new do |text|
    if text
      Rails.cache.write(OXR_CACHE_KEY, text)
    else
      Rails.cache.read(OXR_CACHE_KEY)
    end
  end
end
```

## Pair rates

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

Copyright © 2011-2019 Laurent Arnoud <laurent@spkdev.net>

---
[![Build](https://img.shields.io/travis-ci/spk/money-open-exchange-rates.svg)](https://travis-ci.org/spk/money-open-exchange-rates)
[![Version](https://img.shields.io/gem/v/money-open-exchange-rates.svg)](https://rubygems.org/gems/money-open-exchange-rates)
[![Documentation](https://img.shields.io/badge/doc-rubydoc-blue.svg)](http://www.rubydoc.info/gems/money-open-exchange-rates)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](http://opensource.org/licenses/MIT "MIT")
[![Coverage Status](https://img.shields.io/coveralls/github/spk/money-open-exchange-rates.svg)](https://coveralls.io/github/spk/money-open-exchange-rates?branch=master)
[![Inline docs](https://inch-ci.org/github/spk/money-open-exchange-rates.svg?branch=master)](http://inch-ci.org/github/spk/money-open-exchange-rates)
