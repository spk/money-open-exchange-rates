# encoding: UTF-8
require 'open-uri'
require 'yajl'
require 'money'

class Money
  module Bank
    class InvalidCache < StandardError ; end
    
    class NoAppId < StandardError ; end

    class OpenExchangeRatesBank < Money::Bank::VariableExchange

      OER_URL = 'http://openexchangerates.org/latest.json'

      attr_accessor :cache, :app_id
      attr_reader :doc, :oer_rates, :rates_source

      def update_rates
        exchange_rates.each do |exchange_rate|
          rate = exchange_rate.last
          currency = exchange_rate.first
          next unless Money::Currency.find(currency)
          set_rate('USD', currency, rate)
        end
      end

      def read_from_url
        raise NoAppId if app_id.nil? || app_id == ""
        open(OER_URL + "?app_id=" + app_id).read
      end

      def has_valid_rates?(text)
        parsed = Yajl::Parser.parse(text)
        parsed && parsed.has_key?('rates')
      rescue Yajl::ParseError
        false
      end


      def save_rates
        raise InvalidCache unless cache
        new_text = read_from_url
        if has_valid_rates?(new_text)
          open(cache, 'w') do |f|
            f.write(new_text)
          end
        end
      rescue Errno::ENOENT
        raise InvalidCache
      end

      def exchange(cents, from_currency, to_currency)
        exchange_with(Money.new(cents, from_currency), to_currency)
      end

      def exchange_with(from, to_currency)
        return from if same_currency?(from.currency, to_currency)
        rate = get_rate(from.currency, to_currency)
        unless rate
          from_base_rate = get_rate("USD", from.currency)
          to_base_rate = get_rate("USD", to_currency)
          raise(Money::Bank::UnknownRateFormat, "No conversion rate known for '#{from.currency.iso_code}' -> '#{to_currency}'") if from_base_rate.nil? || to_base_rate.nil?
          rate = to_base_rate.to_f / from_base_rate.to_f
        end
        Money.new(((Money::Currency.wrap(to_currency).subunit_to_unit.to_f / from.currency.subunit_to_unit.to_f) * from.cents * rate).round, to_currency)
      end

      protected

      def find_rates_source
        if !!cache && File.exist?(cache)
          @rates_source = cache
        else
          OER_URL
        end
      end

      def exchange_rates
        @rates_source = find_rates_source
        @doc = Yajl::Parser.parse(open(rates_source).read)
        @oer_rates = @doc['rates']
        @doc['rates']
      end
    end
  end
end
