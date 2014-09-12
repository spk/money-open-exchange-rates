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
# by default, they never expire
moe.ttl_in_seconds = 86400

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

As of the end of August 2012 all requests to the Open Exchange Rates API must
have a valid app_id. You can place your own key on a file or environment
variable named TEST_APP_ID and then run:

~~~
bundle exec rake
~~~

## Refs

* https://github.com/currencybot/open-exchange-rates
* https://github.com/RubyMoney/money
* https://github.com/RubyMoney/eu_central_bank
* https://github.com/RubyMoney/google_currency

## Contributors

* [Wayne See](https://github.com/weynsee)
* [Julien Boyer](https://github.com/chatgris)
* [Kevin Ball](https://github.com/kball)
* [Michael Morris](https://github.com/mtcmorris)

## License

The MIT License

Copyright © 2014 Laurent Arnoud <laurent@spkdev.net>
