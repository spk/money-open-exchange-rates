# Money Open Exchange Rates

A gem that calculates the exchange rate using published rates from [open-exchange-rates](http://josscrowcroft.github.com/open-exchange-rates/)

## Usage

```ruby
require 'money/bank/open_exchange_rates_bank'
moe = Money::Bank::OpenExchangeRatesBank.new
moe.cache = 'path/to/file/cache'

Money.default_bank = moe
```

## Refs

* https://github.com/currencybot/open-exchange-rates
* https://github.com/RubyMoney/money
* https://github.com/RubyMoney/eu_central_bank
* https://github.com/RubyMoney/google_currency

## License
The MIT License

Copyright © 2011 Laurent Arnoud <laurent@spkdev.net>
