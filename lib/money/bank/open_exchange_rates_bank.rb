# frozen_string_literal: true

require 'json'
require 'money'
require 'net/http'
require 'time'
require 'uri'
require File.expand_path('../../open_exchange_rates_bank/version', __dir__)

# Money gem class
# rubocop:disable Metrics/ClassLength
class Money
  # https://github.com/RubyMoney/money#exchange-rate-stores
  module Bank
    # Invalid cache, file not found or cache empty
    class InvalidCache < StandardError; end

    # APP_ID not set error
    class NoAppId < StandardError; end

    # Access restricted (e.g. usage/request limit exceeded for account)
    class AccessRestricted < StandardError; end

    # app_id_inactive
    class AppIdInactive < StandardError; end

    class NoRateError < StandardError; end

    ERROR_MAP = {
      access_restricted: AccessRestricted,
      app_id_inactive: AppIdInactive
    }.freeze

    # OpenExchangeRatesBank base class
    class OpenExchangeRatesBank < Money::Bank::VariableExchange
      VERSION = ::OpenExchangeRatesBank::VERSION
      BASE_URL = 'https://openexchangerates.org/api/'

      # OpenExchangeRates urls
      OER_URL = URI.join(BASE_URL, 'latest.json')
      OER_HISTORICAL_URL = URI.join(BASE_URL, 'historical/')

      # Default base currency "base": "USD"
      OE_SOURCE = 'USD'
      RATES_KEY = 'rates'
      TIMESTAMP_KEY = 'timestamp'

      # As of the end of August 2012 all requests to the Open Exchange Rates
      # API must have a valid app_id
      # see https://docs.openexchangerates.org/docs/authentication
      #
      # @example
      #   oxr.app_id = 'YOUR_APP_APP_ID'
      #
      # @param [String] token to access OXR API
      # @return [String] token to access OXR API
      attr_accessor :app_id

      # Cache accessor
      #
      # @example
      #   oxr.cache = 'path/to/file/cache.json'
      #
      # @param [String,Proc] for a String a filepath
      # @return [String,Proc] for a String a filepath
      attr_accessor :cache

      attr_accessor :fetch_bid_ask_rates

      # Date for historical api
      # see https://docs.openexchangerates.org/docs/historical-json
      #
      # @example
      #   oxr.date = '2015-01-01'
      #
      # @param [String] The requested date in YYYY-MM-DD format
      # @return [String] The requested date in YYYY-MM-DD format
      attr_accessor :date

      # Force refresh rates cache and store on the fly when ttl is expired
      # This will slow down request on get_rate, so use at your on risk, if you
      # don't want to setup crontab/worker/scheduler for your application
      #
      # @param [Boolean]
      attr_accessor :force_refresh_rate_on_expire

      # Rates expiration Time
      #
      # @return [Time] expiration time
      attr_reader :rates_expiration

      # Parsed OpenExchangeRates result as Hash
      #
      # @return [Hash] All rates as Hash
      attr_reader :oer_rates

      # Unparsed OpenExchangeRates response as String
      #
      # @return [String] OpenExchangeRates json response
      attr_reader :json_response

      # Seconds after than the current rates are automatically expired
      #
      # @return [Integer] Setted time to live in seconds
      attr_reader :ttl_in_seconds

      # Set support for the black market and alternative digital currencies
      # see https://docs.openexchangerates.org/docs/alternative-currencies
      # @example
      #   oxr.show_alternative = true
      #
      # @param [Boolean] if true show alternative
      # @return [Boolean] Setted show alternative
      attr_writer :show_alternative

      # Filter response to a list of symbols
      # see https://docs.openexchangerates.org/docs/get-specific-currencies
      # @example
      #   oxr.symbols = [:usd, :cad]
      #
      # @param [Array] list of symbols
      # @return [Array] Setted list of symbols
      attr_writer :symbols

      # Minified Response ('prettyprint')
      # see https://docs.openexchangerates.org/docs/prettyprint
      # @example
      #   oxr.prettyprint = false
      #
      # @param [Boolean] Set to false to receive minified (default: true)
      # @return [Boolean]
      attr_writer :prettyprint

      # Set current rates timestamp
      #
      # @return [Time]
      def rates_timestamp=(at)
        @rates_timestamp = Time.at(at)
      end

      # Current rates timestamp
      #
      # @return [Time]
      def rates_timestamp
        @rates_timestamp || Time.now
      end

      # Set the seconds after than the current rates are automatically expired
      # by default, they never expire.
      #
      # @example
      #   ttl_in_seconds = 86400 # will expire the rates in one day
      #
      # @param value [Integer] Time to live in seconds
      #
      # @return [Integer] Setted time to live in seconds
      def ttl_in_seconds=(value)
        @ttl_in_seconds = value
        refresh_rates_expiration if ttl_in_seconds
        ttl_in_seconds
      end

      # Set the base currency for all rates. By default, USD is used.
      # OpenExchangeRates only allows USD as base currency
      # for the free plan users.
      #
      # @example
      #   oxr.source = 'USD'
      #
      # @param value [String] Currency code, ISO 3166-1 alpha-3
      #
      # @return [String] chosen base currency
      def source=(value)
        scurrency = Money::Currency.find(value.to_s)
        @source = if scurrency
                    scurrency.iso_code
                  else
                    OE_SOURCE
                  end
      end

      # Get the base currency for all rates. By default, USD is used.
      #
      # @return [String] base currency
      def source
        @source ||= OE_SOURCE
      end

      # Update all rates from openexchangerates JSON
      #
      # @return [Array] Array of exchange rates
      def update_rates
        store.transaction do
          clear_rates!
          exchange_rates.each do |exchange_rate|
            currency = exchange_rate.first
            details = exchange_rate.last
      
            # Skip the currency if it's not recognized by the Money gem
            next unless Money::Currency.find(currency)
      
            if details.is_a?(Hash)
              rate = details['rate'] || details['mid']
              rate = rate.to_f if rate
              bid = details['bid'].to_f if fetch_bid_ask_rates && details['bid']
              ask = details['ask'].to_f if fetch_bid_ask_rates && details['ask']
            elsif details.is_a?(Numeric)
              rate = details.to_f
            else
              next
            end
      
            set_rate(source, currency, rate) if rate
            set_rate(currency, source, 1.0 / rate) if rate != 0
      
            if fetch_bid_ask_rates && bid && ask
              set_bid_ask_rates(currency, bid, ask)
            end
          end
        end
      end
      
      
      def initialize
        super
        @fetch_bid_ask_rates = false # Default to not fetching bid/ask unless explicitly enabled
        @symbols = [] 
      end

      # Alias super method
      alias super_get_rate get_rate

      # Override Money `get_rate` method for caching
      #
      # @param [String] from_currency Currency ISO code. ex. 'USD'
      # @param [String] to_currency Currency ISO code. ex. 'CAD'
      #
      # @return [Numeric] rate.
      # Override to include options for fetching bid and ask rates
      def get_rate(from_currency, to_currency, opts = {})
        rate_key = case opts[:rate_type]
                   when :bid then "#{to_currency}_bid"
                   when :ask then "#{to_currency}_ask"
                   else to_currency
                   end
        rate = store.get_rate(from_currency, rate_key)
        puts "Fetching rate for #{from_currency} to #{rate_key}: #{rate}" # Debug output
        unless rate
          raise Money::Bank::NoRateError, "No #{opts[:rate_type]} rate available for #{from_currency} to #{to_currency}"
        end

        rate
      end

      # Fetch from url and save cache
      #
      # @return [Array] Array of exchange rates
      def refresh_rates
        api_url = custom_api_endpoint || build_api_url
        response = fetch_rates_from_api(api_url)
        parse_and_store_data(response) if valid_rates?(response)
      end

      def build_api_url
        base_endpoint = 'latest.json'  # Use the latest.json endpoint
        uri = URI.join(BASE_URL, base_endpoint)
        query_params = {
          app_id: app_id,
          base: source,
          symbols: (symbols || []).join(','),
          show_bid_ask: fetch_bid_ask_rates ? '1' : nil  # Add show_bid_ask parameter
        }
        
        # Filter out nil values but leave the string '1' for show_bid_ask
        uri.query = URI.encode_www_form(query_params.reject { |_, v| v.nil? })
        uri.to_s
      end
      
      
      
      

      def custom_api_endpoint
        # If you have a custom endpoint, return it here
        # For now, returning nil will ensure it defaults to build_api_url
        nil
      end

      def fetch_rates_from_api(url)
        uri = URI(url) # Make sure it is converted to a URI object properly
        response = Net::HTTP.get_response(uri)
        raise "API request failed: #{response.message}" unless response.is_a?(Net::HTTPSuccess)
        response.body
      rescue => e
        raise "Failed to fetch rates from API: #{e.message}"
      end
      



      # New method to parse and store bid and ask rates along with the normal rates
      def parse_and_store_data(json_response)
        data = JSON.parse(json_response)
        puts "Parsed data: #{data}"  # Debugging output
        return unless data[RATES_KEY] && data[TIMESTAMP_KEY]  # Ensure necessary keys exist
      
        store.transaction do
          clear_rates!
          data[RATES_KEY].each do |currency, details|
            if details.is_a?(Hash)
              rate = details['mid'] || details['rate']
              set_rate(source, currency, rate.to_f)
              set_rate(currency, source, 1.0 / rate.to_f) if rate != 0
              if fetch_bid_ask_rates && details['bid'] && details['ask']
                set_bid_ask_rates(currency, details['bid'].to_f, details['ask'].to_f)
              end
            elsif details.is_a?(Numeric)
              rate = details.to_f
              set_rate(source, currency, rate)
              set_rate(currency, source, 1.0 / rate) if rate != 0
            end
          end
        end
      end
      
      
      def valid_rate_details?(details)
        if details.is_a?(Hash)
          details['rate'].is_a?(Numeric) || (fetch_bid_ask_rates && details['bid'].is_a?(Numeric) && details['ask'].is_a?(Numeric))
        else
          details.is_a?(Numeric)
        end
      end
      # Method to store bid and ask rates
      def set_bid_ask_rates(currency, bid, ask)
        puts "Attempting to store rates for #{currency}: bid=#{bid}, ask=#{ask}"
        bid_key = "#{currency}_bid"
        ask_key = "#{currency}_ask"

        # Store bid rate
        store.add_rate(source, bid_key, bid)
        stored_bid = store.get_rate(source, bid_key)
        puts "Stored bid rate for #{bid_key}: #{stored_bid}"
        unless bid == stored_bid
          raise "Failed to store bid rate for #{currency}. Expected: #{bid}, got: #{stored_bid}"
        end

        # Store ask rate
        store.add_rate(source, ask_key, ask)
        stored_ask = store.get_rate(source, ask_key)
        puts "Stored ask rate for #{ask_key}: #{stored_ask}"
        unless ask == stored_ask
          raise "Failed to store ask rate for #{currency}. Expected: #{ask}, got: #{stored_ask}"
        end
      end

      # Alias refresh_rates method
      alias save_rates refresh_rates

      # Expire rates when expired
      #
      # @return [NilClass, Time] nil if not expired or new expiration time
      def expire_rates
        return unless ttl_in_seconds
        return if rates_expiration > Time.now

        refresh_rates if force_refresh_rate_on_expire
        update_rates
        refresh_rates_expiration
      end

      # Get show alternative
      #
      # @return [Boolean] if true show alternative
      def show_alternative
        @show_alternative ||= false
      end

      # Get prettyprint option
      #
      # @return [Boolean]
      def prettyprint
        return true unless defined? @prettyprint
        return true if @prettyprint.nil?

        @prettyprint
      end

      # Get symbols
      #
      # @return [Array] list of symbols to filter by
      def symbols
        @symbols ||= nil
      end

      # Source url of openexchangerates
      # defined with app_id
      #
      # @return [String] URL
      def source_url
        str = "#{oer_url}?app_id=#{app_id}"
        str = "#{str}&base=#{source}" unless source == OE_SOURCE
        str = "#{str}&show_alternative=#{show_alternative}"
        str = "#{str}&prettyprint=#{prettyprint}"
        str = "#{str}&symbols=#{symbols.join(',')}" if symbols&.is_a?(Array)
        str
      end

      protected

      # Save rates on cache
      # Can raise InvalidCache
      #
      # @return [Proc,File]
      def save_cache
        store_in_cache(@json_response) if valid_rates?(@json_response)
      rescue Errno::ENOENT
        raise InvalidCache
      end

      # Latest url if no date given
      #
      # @return [String] URL
      def oer_url
        if date
          historical_url
        else
          latest_url
        end
      end

      # Historical url generated from `date` attr_accessor
      #
      # @return [String] URL
      def historical_url
        URI.join(OER_HISTORICAL_URL, "#{date}.json")
      end

      # Latest url
      #
      # @return [String] URL
      def latest_url
        OER_URL
      end

      # Store the provided text data by calling the proc method provided
      # for the cache, or write to the cache file.
      # Can raise InvalidCache
      #
      # @example
      #   oxr.store_in_cache("{\"rates\": {\"AED\": 3.67304}}")
      #
      # @param text [String] String to cache
      # @return [String,Integer]
      def store_in_cache(text)
        if cache.is_a?(Proc)
          cache.call(text)
        elsif cache.is_a?(String) || cache.is_a?(Pathname)
          File.open(cache.to_s, 'w') do |f|
            f.write(text)
          end
        else
          raise InvalidCache
        end
      end

      # Read from cache when exist
      #
      # @return [String] Raw string from file or cache proc
      def read_from_cache
        result = if cache.is_a?(Proc)
                   cache.call(nil)
                 elsif File.exist?(cache.to_s)
                   File.read(cache)
                 end
        result if valid_rates?(result)
      end

      # Read API
      #
      # @return [String]
      def api_response
        Net::HTTP.get(URI(source_url))
      end

      # Read from url
      #
      # @return [String] JSON content
      def read_from_url
        raise NoAppId if app_id.nil? || app_id.empty?

        @json_response = api_response
        save_cache if cache
        @json_response
      end

      # Check validity of rates response only for store in cache
      #
      # @example
      #   oxr.valid_rates?("{\"rates\": {\"AED\": 3.67304}}")
      #
      # @param [String] text is JSON content
      # @return [Boolean] valid or not
      def valid_rates?(text)
        return false unless text
      
        parsed = JSON.parse(text)
        valid = parsed.key?(RATES_KEY) && parsed.key?(TIMESTAMP_KEY)
        valid &&= parsed[RATES_KEY].all? do |_, v|
          v.is_a?(Numeric) || (v.is_a?(Hash) && (v.key?('mid') || v.key?('rate')) && (!fetch_bid_ask_rates || (v.key?('bid') && v.key?('ask'))))
        end
        valid
      rescue JSON::ParserError
        false
      end
      

      # Get expire rates, first from cache and then from url
      #
      # @return [Hash] key is country code (ISO 3166-1 alpha-3) value Float
      def exchange_rates
        doc = JSON.parse(read_from_cache || read_from_url)
        if doc['error'] && ERROR_MAP.key?(doc['message'].to_sym)
          raise ERROR_MAP[doc['message'].to_sym]
        end

        self.rates_timestamp = doc[TIMESTAMP_KEY]
        @oer_rates = doc[RATES_KEY]
      end

      # Refresh expiration from now
      #
      # @return [Time] new expiration time
      def refresh_rates_expiration
        @rates_expiration = rates_timestamp + ttl_in_seconds
      end

      # Get rate or calculate it as inverse rate
      #
      # @param [String] from_currency Currency ISO code. ex. 'USD'
      # @param [String] to_currency Currency ISO code. ex. 'CAD'
      #
      # @return [Numeric] rate or rate calculated as inverse rate.
      def get_rate_or_calc_inverse(from_currency, to_currency, opts = {})
        rate = super_get_rate(from_currency, to_currency, opts)
        unless rate
          # Tries to calculate an inverse rate
          inverse_rate = super_get_rate(to_currency, from_currency, opts)
          if inverse_rate
            rate = 1.0 / inverse_rate
            add_rate(from_currency, to_currency, rate)
          end
        end
        rate
      end

      # Tries to calculate a pair rate using base currency rate
      #
      # @param [String] from_currency Currency ISO code. ex. 'USD'
      # @param [String] to_currency Currency ISO code. ex. 'CAD'
      #
      # @return [Numeric] rate or nil if cannot calculate rate.
      def calc_pair_rate_using_base(from_currency, to_currency, opts)
        from_base_rate = get_rate_or_calc_inverse(source, from_currency, opts)
        to_base_rate   = get_rate_or_calc_inverse(source, to_currency, opts)
        return unless to_base_rate
        return unless from_base_rate

        rate = BigDecimal(to_base_rate.to_s) / from_base_rate
        add_rate(from_currency, to_currency, rate)
        rate
      end

      # Clears cached rates in store
      #
      # @return [Hash] All rates from store as Hash
      def clear_rates!
        store.each_rate do |iso_from, iso_to|
          add_rate(iso_from, iso_to, nil)
        end
      end
    end
  end
end
# rubocop:enable Metrics/ClassLength
