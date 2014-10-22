# encoding: UTF-8
require 'open-uri'
require 'money'
require 'json'

class Money
  module Bank
    class InvalidCache < StandardError ; end

    class NoAppId < StandardError ; end

    class OpenExchangeRatesBank < Money::Bank::VariableExchange

      OER_URL = 'http://openexchangerates.org/latest.json'

      attr_accessor :cache, :app_id
      attr_reader :doc, :oer_rates, :rates_expiration, :ttl_in_seconds

      def ttl_in_seconds=(value)
        @ttl_in_seconds = value
        refresh_rates_expiration if ttl_in_seconds
      end

      def update_rates
        exchange_rates.each do |exchange_rate|
          rate = exchange_rate.last
          currency = exchange_rate.first
          next unless Money::Currency.find(currency)
          set_rate('USD', currency, rate)
          set_rate(currency, 'USD', 1.0/rate)
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

      def get_rate(from_currency, to_currency, opts = {})
        expire_rates
        super
      end

      def expire_rates
        if ttl_in_seconds && rates_expiration <= Time.now
          update_rates
          refresh_rates_expiration
        end
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
        end
      end

      def read_from_cache
        if cache.is_a?(Proc)
          cache.call(nil)
        elsif cache.is_a?(String) && File.exist?(cache)
          open(cache).read
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
        parsed = JSON.parse(text)
        parsed && parsed.has_key?('rates')
      rescue JSON::ParserError
        false
      end

      def exchange_rates
        @doc = JSON.parse(read_from_cache || read_from_url)
        @oer_rates = @doc['rates']
        @doc['rates']
      end

      def refresh_rates_expiration
        @rates_expiration = Time.now + ttl_in_seconds
      end
    end
  end
end
