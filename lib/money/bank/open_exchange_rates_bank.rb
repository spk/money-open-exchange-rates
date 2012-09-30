# encoding: UTF-8
require 'open-uri'
require 'multi_json'
require 'money'

class Money
  module Bank
    class InvalidCache < StandardError ; end

    class NoAppId < StandardError ; end

    class OpenExchangeRatesBank < Money::Bank::VariableExchange

      OER_URL = 'http://openexchangerates.org/latest.json'

      attr_accessor :cache, :app_id
      attr_reader :doc, :oer_rates

      def update_rates
        exchange_rates.each do |exchange_rate|
          rate = exchange_rate.last
          currency = exchange_rate.first
          next unless Money::Currency.find(currency)
          set_rate('USD', currency, rate)
        end
      end

      def save_rates
        raise InvalidCache unless cache
        text = read_from_url
        if has_valid_rates?(text)
          store_in_cache(text)
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

      # Store the provided text data by calling the proc method provided
      # for the cache, or write to the cache file.
      def store_in_cache(text)
        if cache.is_a?(Proc)
          cache.call(text)
        elsif cache.is_a?(String)
          open(cache, 'w') do |f|
            f.write(text)
          end
        else
          nil
        end
      end

      def read_from_cache
        if cache.is_a?(Proc)
          cache.call(nil)
        elsif cache.is_a?(String) && File.exist?(cache)
          open(cache).read
        else
          nil
        end
      end

      def source_url
        raise NoAppId if app_id.nil? || app_id.empty?
        "#{OER_URL}?app_id=#{app_id}"
      end

      def read_from_url
        open(source_url).read
      end

      def has_valid_rates?(text)
        parsed = MultiJson.decode(text)
        parsed && parsed.has_key?('rates')
      rescue MultiJson::DecodeError
        false
      end

      def exchange_rates
        @doc = MultiJson.decode(read_from_cache || read_from_url)
        @oer_rates = @doc['rates']
        @doc['rates']
      end
    end
  end
end
