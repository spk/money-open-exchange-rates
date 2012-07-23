# Money Open Exchange Rates

A gem that calculates the exchange rate using published rates from [open-exchange-rates](http://josscrowcroft.github.com/open-exchange-rates/)

## Usage

```ruby
require 'money/bank/open_exchange_rates_bank'
moe = Money::Bank::OpenExchangeRatesBank.new
moe.cache = 'path/to/file/cache'
moe.update_rates

Money.default_bank = moe
```

## Tests

  bundle exec ruby test/open_exchange_rates_bank_test.rb

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

Copyright © 2012 Laurent Arnoud <laurent@spkdev.net>
