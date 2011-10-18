# encoding: UTF-8
require 'open-uri'
require 'yajl'
require 'money'

class Money
  module Bank
    class InvalidCache < StandardError ; end

    class OpenExchangeRatesBank < Money::Bank::VariableExchange

      OER_URL = 'http://openexchangerates.org/latest.php'

      attr_accessor :cache
      attr_reader :doc, :oer_rates, :rates_source

      def update_rates
        exchange_rates.each do |exchange_rate|
          rate = exchange_rate.last
          currency = exchange_rate.first
          set_rate('USD', currency, rate)
        end
      end

      def save_rates
        raise InvalidCache unless cache
        open(cache, 'w').write(open(OER_URL).read)
      end

      def exchange(cents, from_currency, to_currency)
        exchange_with(Money.new(cents, from_currency), to_currency)
      end

      def exchange_with(from, to_currency)
        rate = get_rate(from.currency, to_currency)
        unless rate
          from_base_rate = get_rate("USD", from.currency)
          to_base_rate = get_rate("USD", to_currency)
          rate = to_base_rate / from_base_rate
        end
        Money.new(((Money::Currency.wrap(to_currency).subunit_to_unit.to_f / from.currency.subunit_to_unit.to_f) * from.cents * rate).round, to_currency)
      end

      protected

      def exchange_rates
        @rates_source = !!cache ? cache : OER_URL
        @doc = Yajl::Parser.parse(open(rates_source).read)
        @oer_rates = @doc['rates']
        @doc['rates']
      end
    end
  end
end
