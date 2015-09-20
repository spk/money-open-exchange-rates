require 'money'

class Money
  # https://github.com/RubyMoney/money#exchange-rate-stores
  module Bank
    # OpenExchangeRatesBank base class
    class OpenExchangeRatesBank < Money::Bank::VariableExchange
      VERSION = '0.3.1'
    end
  end
end
