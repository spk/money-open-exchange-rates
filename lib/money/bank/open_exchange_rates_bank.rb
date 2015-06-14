# encoding: UTF-8
require 'open-uri'
require 'money'
require 'json'

class Money
  module Bank
    class InvalidCache < StandardError; end

    class NoAppId < StandardError; end

    # OpenExchangeRatesBank base class
    class OpenExchangeRatesBank < Money::Bank::VariableExchange
      OER_URL = 'http://openexchangerates.org/latest.json'
      SECURE_OER_URL = OER_URL.tr('http:', 'https:')

      attr_accessor :cache, :app_id, :secure_connection
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
          set_rate(currency, 'USD', 1.0 / rate)
        end
      end

      def save_rates
        fail InvalidCache unless cache
        text = read_from_url
        store_in_cache(text) if valid_rates?(text)
      rescue Errno::ENOENT
        raise InvalidCache
      end

      def get_rate(from_currency, to_currency, opts = {})
        expire_rates
        super
      end

      def expire_rates
        return unless ttl_in_seconds
        return if rates_expiration > Time.now
        update_rates
        refresh_rates_expiration
      end

      def source_url
        fail NoAppId if app_id.nil? || app_id.empty?
        oer_url = OER_URL
        oer_url = SECURE_OER_URL if secure_connection
        "#{oer_url}?app_id=#{app_id}"
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

      def read_from_url
        open(source_url).read
      end

      def valid_rates?(text)
        parsed = JSON.parse(text)
        parsed && parsed.key?('rates')
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
