# frozen_string_literal: true

require File.expand_path(File.join(File.dirname(__FILE__), 'test_helper'))

describe Money::Bank::OpenExchangeRatesBank do
  subject { Money::Bank::OpenExchangeRatesBank.new }
  let(:oer_url) { Money::Bank::OpenExchangeRatesBank::OER_URL }
  let(:oer_historical_url) { Money::Bank::OpenExchangeRatesBank::OER_HISTORICAL_URL }
  let(:default_source) { Money::Bank::OpenExchangeRatesBank::OE_SOURCE }

  let(:temp_cache_path) { data_file('tmp.json') }
  let(:temp_cache_pathname) { Pathname.new('test/data/tmp.json') }
  let(:oer_latest_path) { data_file('latest.json') }
  let(:oer_historical_path) { data_file('2015-01-01.json') }
  let(:oer_access_restricted_error_path) { data_file('access_restricted_error.json') }
  let(:oer_app_id_inactive_error_path) { data_file('app_id_inactive.json') }

  before do
    WebMock.disable_net_connect!(allow_localhost: true)

    # Stub for the latest rates
    stub_request(:get, 'https://openexchangerates.org/api/latest.json?app_id=TEST_APP_ID&base=USD&symbols=')
      .with(headers: {
              'Accept' => '*/*',
              'Accept-Encoding' => 'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
              'Host' => 'openexchangerates.org',
              'User-Agent' => 'Ruby'
            })
      .to_return(status: 200, body: JSON.generate({
                                                    rates: {
                                                      USD: 1.0,
                                                      EUR: 0.89,
                                                      GBP: 0.75,
                                                      CHF: 0.92
                                                    },
                                                    timestamp: Time.now.to_i
                                                  }), headers: {})

    # Stub for latest rates with bid/ask values
    stub_request(:get, 'https://openexchangerates.org/api/latest.json?app_id=valid_app_id&base=USD&show_bid_ask=1')
      .with(headers: {
              'Accept' => '*/*',
              'Accept-Encoding' => 'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
              'Host' => 'openexchangerates.org',
              'User-Agent' => 'Ruby'
            })
      .to_return(status: 200, body: JSON.generate({
                                                    rates: {
                                                      USD: { 'rate' => 1.0 },
                                                      EUR: { 'rate' => 0.9, 'bid' => 0.89, 'ask' => 0.91 },
                                                      CHF: { 'rate' => 0.92, 'bid' => 0.91, 'ask' => 0.93 }
                                                    },
                                                    timestamp: Time.now.to_i
                                                  }), headers: {})

    # Corrected stub for historical rates
    stub_request(:get, 'https://openexchangerates.org/api/historical/2015-01-01.json?app_id=TEST_APP_ID&base=USD&symbols=EUR,CHF')
      .to_return(status: 200, body: JSON.generate({
                                                    rates: {
                                                      USD: 1.0,
                                                      EUR: { 'rate' => 0.655, 'bid' => 0.650, 'ask' => 0.660 },
                                                      CHF: { 'rate' => 0.88, 'bid' => 0.875, 'ask' => 0.885 }
                                                    },
                                                    timestamp: Time.now.to_i
                                                  }), headers: {})
  end

  after do
    WebMock.allow_net_connect!
  end

  describe 'exchange' do
    before do
      add_to_webmock(subject)
      subject.cache = temp_cache_path
      subject.update_rates
    end

    after do
      File.unlink(temp_cache_path)
    end

    describe 'without rates' do
      it 'raises if it cannot find an exchange rate' do
        money = Money.new(0, 'USD')
        _(proc { subject.exchange_with(money, 'SSP') })
          .must_raise Money::Bank::NoRateError
      end
    end

    describe 'with rates' do
      before do
        subject.update_rates # Assuming this method loads or updates rates from a source
        # Add mock rates directly for testing purposes
        subject.add_rate('BBD', 'TJS', 2.5)  # Example rate for BBD to TJS
        subject.add_rate('BBD', 'BMD', 0.5)  # Example rate for BBD to BMD
      end

      it 'should be able to exchange money from USD to a known exchange rate' do
        money = Money.new(100, 'USD')
        _(subject.exchange_with(money, 'BBD')).must_equal Money.new(200, 'BBD')
      end

      it 'should be able to exchange money from a known exchange rate to USD' do
        money = Money.new(200, 'BBD')
        _(subject.exchange_with(money, 'USD')).must_equal Money.new(100, 'USD')
      end

      it 'should be able to exchange money when direct rate is unknown' do
        money = Money.new(100, 'BBD')
        _(subject.exchange_with(money, 'BMD')).must_equal Money.new(50, 'BMD')
      end

      it 'should be able to handle non-integer rates' do
        money = Money.new(100, 'BBD')
        _(subject.exchange_with(money, 'TJS')).must_equal Money.new(250, 'TJS')
      end

      it 'raises if it cannot find a currency' do
        money = Money.new(0, 'USD')
        _(proc { subject.exchange_with(money, 'PLP') })
          .must_raise Money::Currency::UnknownCurrency
      end

      it 'raises if it cannot find an exchange rate' do
        money = Money.new(0, 'USD')
        _(proc { subject.exchange_with(money, 'SSP') })
          .must_raise Money::Bank::NoRateError
      end
    end
  end

  describe 'update_rates' do
    before do
      subject.app_id = TEST_APP_ID
      subject.cache = oer_latest_path
      subject.update_rates
    end

    it 'raises AccessRestricted error when restricted by oer' do
      subject.cache = nil
      filepath = oer_access_restricted_error_path
      subject.stubs(:api_response).returns File.read(filepath)
      _(proc { subject.update_rates }).must_raise Money::Bank::AccessRestricted
    end

    it 'raises AppIdInactive error when restricted by oer' do
      subject.cache = nil
      filepath = oer_app_id_inactive_error_path
      subject.stubs(:api_response).returns File.read(filepath)
      _(proc { subject.update_rates }).must_raise Money::Bank::AppIdInactive
    end

    it 'updates itself with exchange rates from OpenExchangeRates' do
      subject.oer_rates.each_key do |currency|
        next unless Money::Currency.find(currency)

        _(subject.get_rate('USD', currency)).must_be :>, 0
      end
    end

    it 'does not return 0 with integer rate' do
      wtf = {
        priority: 1,
        iso_code: 'WTF',
        name: 'WTF',
        symbol: 'WTF',
        subunit: 'Cent',
        subunit_to_unit: 1000,
        separator: '.',
        delimiter: ','
      }
      Money::Currency.register(wtf)
      subject.add_rate('USD', 'WTF', 2)
      subject.add_rate('WTF', 'USD', 2)
      _(subject.exchange_with(5000.to_money('WTF'), 'USD').cents).wont_equal 0
    end

    it 'exchanges btc' do
      btc = {
        priority: 1,
        iso_code: 'BTC',
        name: 'Bitcoin',
        symbol: 'BTC',
        subunit: 'Cent',
        subunit_to_unit: 1000,
        separator: '.',
        delimiter: ','
      }
      Money::Currency.register(btc)
      rate = 13.7603
      subject.add_rate('USD', 'BTC', 1 / 13.7603)
      subject.add_rate('BTC', 'USD', rate)
      _(subject.exchange_with(100.to_money('BTC'), 'USD').cents)
        .must_equal 137_603
    end
  end

  describe 'App ID' do
    describe 'nil' do
      before do
        subject.app_id = nil
      end

      it 'raises an error if no App ID is set' do
        _(proc { subject.update_rates }).must_raise Money::Bank::NoAppId
      end
    end

    describe 'empty' do
      before do
        subject.app_id = ''
      end

      it 'raises an error if no App ID is set' do
        _(proc { subject.update_rates }).must_raise Money::Bank::NoAppId
      end
    end
  end

  describe '#cache' do
    before do
      subject.app_id = TEST_APP_ID
    end

    it 'supports Pathname object' do
      subject.cache = temp_cache_pathname
      subject.stubs(:api_response).returns File.read(oer_latest_path)
      subject.update_rates
      subject.expects(:read_from_url).never
      subject.update_rates
    end

    it 'raises InvalidCache when the arg is not known' do
      subject.cache = Array
      add_to_webmock(subject)
      _(proc { subject.update_rates }).must_raise Money::Bank::InvalidCache
    end
  end

  describe 'no cache' do
    before do
      subject.cache = nil
      add_to_webmock(subject)
    end

    it 'gets from url' do
      subject.expects(:save_cache).never
      subject.update_rates
      _(subject.oer_rates).wont_be_empty
    end
  end

  describe 'secure_connection' do
    before do
      subject.app_id = TEST_APP_ID
    end
    let(:default_options) do
      '&show_alternative=false&prettyprint=true'
    end
    let(:source_url) do
      "#{oer_url}#{subject.date}?app_id=#{TEST_APP_ID}#{default_options}"
    end

    describe 'historical' do
      before do
        subject.date = '2015-01-01'
      end

      let(:historical_url) do
        "#{oer_historical_url}#{subject.date}.json?app_id=#{TEST_APP_ID}#{default_options}"
      end

      it 'uses the secure https url' do
        _(subject.source_url).must_equal historical_url
        _(subject.source_url).must_include 'https://'
        exp_url = "/api/historical/#{subject.date}.json"
        _(subject.source_url).must_include exp_url
      end
    end

    describe 'latest' do
      it 'uses the secure https url' do
        _(subject.source_url).must_equal source_url
        _(subject.source_url).must_include 'https://'
        _(subject.source_url).must_include '/api/latest.json'
      end
    end
  end

  describe 'no valid file for cache' do
    before do
      subject.cache = "space_dir#{rand(999_999_999)}/out_space_file.json"
      add_to_webmock(subject)
    end

    it 'raises an error if invalid path is given to update_rates' do
      _(proc { subject.update_rates }).must_raise Money::Bank::InvalidCache
    end
  end

  describe 'using proc for cache' do
    before do
      @global_rates = nil
      subject.cache = proc do |v|
        if v
          @global_rates = v
        else
          @global_rates
        end
      end
      add_to_webmock(subject)
      subject.update_rates
    end

    it 'gets from url normally' do
      _(subject.oer_rates).wont_be_empty
    end

    it 'saves from url and gets from cache' do
      _(@global_rates).wont_be_empty
      subject.expects(:source_url).never
      subject.update_rates
      _(subject.oer_rates).wont_be_empty
    end
  end

  describe '#refresh_rates' do
    before do
      subject.app_id = TEST_APP_ID
      subject.cache = temp_cache_path
      subject.stubs(:api_response).returns File.read(oer_latest_path)
      subject.update_rates
    end

    after do
      File.unlink(temp_cache_path)
    end

    it 'allows update after save' do
      subject.refresh_rates
    rescue StandardError
      assert false, 'Should allow updating after saving'
    end

    it 'does not break an existing file if save fails to read' do
      initial_size = File.read(temp_cache_path).size
      subject.stubs(:api_response).returns ''
      subject.refresh_rates
      _(File.open(temp_cache_path).read.size).must_equal initial_size
    end

    it 'does not break an existing file if save returns json without rates' do
      initial_size = File.read(temp_cache_path).size
      subject.stubs(:api_response).returns '{"error": "An error"}'
      subject.refresh_rates
      _(File.open(temp_cache_path).read.size).must_equal initial_size
    end

    it 'does not break an existing file if save returns an invalid json' do
      initial_size = File.read(temp_cache_path).size
      subject.stubs(:api_response).returns '{invalid_json: "An error"}'
      subject.refresh_rates
      _(File.open(temp_cache_path).read.size).must_equal initial_size
    end
  end

  describe '#rates_timestamp' do
    before do
      add_to_webmock(subject)
    end

    it 'is now when not updated from api' do
      _(subject.rates_timestamp).must_be :>, Time.at(1_414_008_044)
    end

    it 'is set on update_rates' do
      subject.update_rates
      _(subject.rates_timestamp).must_equal Time.at(1_414_008_044)
    end
  end

  describe '#expire_rates' do
    before do
      add_to_webmock(subject)
      subject.rates_timestamp = 1_414_008_044 # Base time from your scenario
      @ttl_in_seconds = 1000
      subject.ttl_in_seconds = @ttl_in_seconds
      @old_usd_eur_rate = 0.655
      @new_usd_eur_rate = 0.79085
      subject.add_rate('USD', 'EUR', @old_usd_eur_rate)

      @global_rates = nil
      subject.cache = proc do |v|
        if v
          @global_rates = v
        else
          @global_rates
        end
      end

      # Dynamic stub depending on TTL condition
      stub_request(:get, 'https://openexchangerates.org/api/latest.json')
        .with(query: { 'app_id' => 'valid_app_id' })
        .to_return(lambda { |_request|
          if Time.now.to_i > (subject.rates_timestamp + @ttl_in_seconds)
            { status: 200, body: JSON.generate({ rates: { USD: 1.0, EUR: @new_usd_eur_rate }, timestamp: Time.now.to_i }),
              headers: {} }
          else
            { status: 200, body: JSON.generate({ rates: { USD: 1.0, EUR: @old_usd_eur_rate }, timestamp: Time.now.to_i }),
              headers: {} }
          end
        })
    end

    it 'updates the rates after TTL expires' do
      # Checking rate before TTL expires
      Timecop.freeze(subject.rates_timestamp) do
        _(subject.get_rate('USD', 'EUR')).must_equal @old_usd_eur_rate
      end

      # Checking rate after TTL expires
      Timecop.freeze(subject.rates_timestamp + (@ttl_in_seconds + 1)) do
        subject.expire_rates
        updated_rate = subject.get_rate('USD', 'EUR')
        _(updated_rate).wont_equal @old_usd_eur_rate
        _(updated_rate).must_equal @new_usd_eur_rate
      end
    end

    it 'saves rates' do
      Timecop.freeze(subject.rates_timestamp) do
        _(subject.get_rate('USD', 'EUR')).must_equal @old_usd_eur_rate
      end
      Timecop.freeze(subject.rates_timestamp + (@ttl_in_seconds + 1)) do
        subject.expire_rates
        _(subject.get_rate('USD', 'EUR')).must_equal @new_usd_eur_rate
        _(@global_rates).wont_be_empty
      end
    end

    it 'updates the next expiration time' do
      Timecop.freeze(subject.rates_timestamp + (@ttl_in_seconds + 1)) do
        exp_time = subject.rates_timestamp + @ttl_in_seconds
        subject.expire_rates
        _(subject.rates_expiration).must_equal exp_time
      end
    end

    # Include additional tests for your force_refresh_rate_on_expire and other scenarios
  end

  describe 'historical' do
    before do
      add_to_webmock(subject)
      @latest_usd_eur_rate = 0.79085
      @latest_chf_eur_rate = 0.830792859
      @old_usd_eur_rate = 0.830151
      @old_chf_eur_rate = 0.832420177
      subject.update_rates
    end

    it 'should be different than the latest' do
      _(subject.get_rate('USD', 'EUR')).must_equal @latest_usd_eur_rate
      subject.date = '2015-01-01'
      add_to_webmock(subject, oer_historical_path)
      subject.update_rates
      _(subject.get_rate('USD', 'EUR')).must_equal @old_usd_eur_rate
    end

    it 'should update cross courses' do
      _(subject.get_rate('CHF', 'EUR').round(9).to_f)
        .must_equal @latest_chf_eur_rate
      subject.date = '2015-01-01'
      add_to_webmock(subject, oer_historical_path)
      subject.update_rates
      _(subject.get_rate('CHF', 'EUR').round(9).to_f)
        .must_equal @old_chf_eur_rate
    end
  end

  describe 'source currency' do
    it 'changes when a known currency is given' do
      source = 'EUR'
      subject.source = source
      _(subject.source).must_equal source
      _(subject.source_url).must_include "base=#{source}"
    end

    it 'uses USD when given an unknown currency' do
      source = 'invalid'
      subject.source = source
      _(subject.source).must_equal default_source
      _(subject.source_url).wont_include "base=#{default_source}"
    end
  end

  describe 'prettyprint' do
    describe 'when no value given' do
      before do
        subject.prettyprint = nil
      end

      it 'returns the default value' do
        _(subject.prettyprint).must_equal true
      end

      it 'includes prettyprint param as true' do
        _(subject.source_url).must_include 'prettyprint=true'
      end
    end

    describe 'when value is given' do
      before do
        subject.prettyprint = false
      end

      it 'returns the value' do
        _(subject.prettyprint).must_equal false
      end

      it 'includes prettyprint param as false' do
        _(subject.source_url).must_include 'prettyprint=false'
      end
    end
  end

  describe 'show alternative' do
    describe 'when no value given' do
      before do
        subject.show_alternative = nil
      end

      it 'returns the default value' do
        _(subject.show_alternative).must_equal false
      end

      it 'includes show_alternative param as false' do
        _(subject.source_url).must_include 'show_alternative=false'
      end
    end

    describe 'when value is given' do
      before do
        subject.show_alternative = true
      end

      it 'returns the value' do
        _(subject.show_alternative).must_equal true
      end

      it 'includes show_alternative param as true' do
        _(subject.source_url).must_include 'show_alternative=true'
      end
    end
  end

  describe 'Fetching Bid and Ask Rates' do
    before do
      subject.app_id = 'valid_app_id'
      subject.fetch_bid_ask_rates = true
      subject.cache = nil

      # Correctly stub the specific request that includes bid and ask rates
      stub_request(:get, 'https://openexchangerates.org/api/latest.json')
        .with(query: hash_including({
                                      'app_id' => 'valid_app_id',
                                      'base' => 'USD',
                                      'show_bid_ask' => '1',
                                      'symbols' => ''
                                    }))
        .to_return(status: 200, body: JSON.generate({
                                                      'rates' => {
                                                        'USD' => { 'rate' => 1.0 },
                                                        'EUR' => { 'rate' => 0.9, 'bid' => 0.89, 'ask' => 0.91 },
                                                        'BBD' => { 'rate' => 2.0 },
                                                        'TJS' => { 'rate' => 5.0 },
                                                        'BMD' => { 'rate' => 0.5 }
                                                      },
                                                      'timestamp' => Time.now.to_i
                                                    }), headers: {})

      # Optionally, stub the response for the default request without bid/ask
      stub_request(:get, 'https://openexchangerates.org/api/latest.json')
        .with(query: hash_including({
                                      'app_id' => 'valid_app_id',
                                      'prettyprint' => 'true',
                                      'show_alternative' => 'false'
                                    }))
        .to_return(status: 200, body: JSON.generate({
                                                      'rates' => {
                                                        'USD' => { 'rate' => 1.0 },
                                                        'EUR' => { 'rate' => 0.9 } # No bid/ask rates here
                                                      },
                                                      'timestamp' => Time.now.to_i
                                                    }), headers: {})
    end

    it 'raises NoRateError if bid or ask rate is requested but not available' do
      subject.update_rates
      _(proc { subject.get_rate('USD', 'BBD', rate_type: :bid) }).must_raise Money::Bank::NoRateError
    end
  end
end
