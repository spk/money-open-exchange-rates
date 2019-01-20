require File.expand_path(File.join(File.dirname(__FILE__), 'test_helper'))

# rubocop:disable Metrics/BlockLength
describe Money::Bank::OpenExchangeRatesBank do
  subject { Money::Bank::OpenExchangeRatesBank.new }
  let(:oer_url) { Money::Bank::OpenExchangeRatesBank::OER_URL }
  let(:oer_historical_url) do
    Money::Bank::OpenExchangeRatesBank::OER_HISTORICAL_URL
  end
  let(:default_source) do
    Money::Bank::OpenExchangeRatesBank::OE_SOURCE
  end

  let(:temp_cache_path) do
    data_file('tmp.json')
  end
  let(:oer_latest_path) do
    data_file('latest.json')
  end
  let(:oer_historical_path) do
    data_file('2015-01-01.json')
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
      it 'able to exchange a money to its own currency even without rates' do
        money = Money.new(0, 'USD')
        subject.exchange_with(money, 'USD').must_equal money
      end

      it "raise if it can't find an exchange rate" do
        money = Money.new(0, 'USD')
        proc { subject.exchange_with(money, 'SSP') }
          .must_raise Money::Bank::UnknownRate
      end
    end

    describe 'with rates' do
      before do
        subject.update_rates
      end

      it 'should be able to exchange money from USD to a known exchange rate' do
        money = Money.new(100, 'USD')
        subject.exchange_with(money, 'BBD').must_equal Money.new(200, 'BBD')
      end

      it 'should be able to exchange money from a known exchange rate to USD' do
        money = Money.new(200, 'BBD')
        subject.exchange_with(money, 'USD').must_equal Money.new(100, 'USD')
      end

      it 'should be able to exchange money when direct rate is unknown' do
        money = Money.new(100, 'BBD')
        subject.exchange_with(money, 'BMD').must_equal Money.new(50, 'BMD')
      end

      it 'should be able to handle non integer rates' do
        money = Money.new(100, 'BBD')
        subject.exchange_with(money, 'TJS').must_equal Money.new(250, 'TJS')
      end

      it "should raise if it can't find an currency" do
        money = Money.new(0, 'USD')
        proc { subject.exchange_with(money, 'PLP') }
          .must_raise Money::Currency::UnknownCurrency
      end

      it "should raise if it can't find an exchange rate" do
        money = Money.new(0, 'USD')
        proc { subject.exchange_with(money, 'SSP') }
          .must_raise Money::Bank::UnknownRate
      end
    end
  end

  describe 'update_rates' do
    before do
      subject.app_id = TEST_APP_ID
      subject.cache = oer_latest_path
      subject.update_rates
    end

    it 'should update itself with exchange rates from OpenExchangeRates' do
      subject.oer_rates.keys.each do |currency|
        next unless Money::Currency.find(currency)

        subject.get_rate('USD', currency).must_be :>, 0
      end
    end

    it 'should not return 0 with integer rate' do
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
      subject.exchange_with(5000.to_money('WTF'), 'USD').cents.wont_equal 0
    end

    # in response to #4
    it 'should exchange btc' do
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
      subject.exchange_with(100.to_money('BTC'), 'USD').cents.must_equal 137_603
    end
  end

  describe 'App ID' do
    before do
      subject.cache = temp_cache_path
    end

    it 'should raise an error if no App ID is set' do
      proc { subject.update_rates }.must_raise Money::Bank::NoAppId
    end
  end

  describe 'no cache' do
    before do
      subject.cache = nil
      add_to_webmock(subject)
    end

    it 'should get from url' do
      subject.expects(:save_cache).never
      subject.update_rates
      subject.oer_rates.wont_be_empty
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
        "#{oer_historical_url}#{subject.date}.json?app_id=#{TEST_APP_ID}" \
          "#{default_options}"
      end

      it 'should use the secure https url' do
        subject.source_url.must_equal historical_url
        subject.source_url.must_include 'https://'
        subject.source_url.must_include "/api/historical/#{subject.date}.json"
      end
    end

    describe 'latest' do
      it 'should use the secure https url' do
        subject.source_url.must_equal source_url
        subject.source_url.must_include 'https://'
        subject.source_url.must_include '/api/latest.json'
      end
    end
  end

  describe 'no valid file for cache' do
    before do
      subject.cache = "space_dir#{rand(999_999_999)}/out_space_file.json"
      add_to_webmock(subject)
    end

    it 'should raise an error if invalid path is given to update_rates' do
      proc { subject.update_rates }.must_raise Money::Bank::InvalidCache
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

    it 'should get from url normally' do
      subject.oer_rates.wont_be_empty
    end

    it 'should save from url and get from cache' do
      @global_rates.wont_be_empty
      subject.expects(:source_url).never
      subject.update_rates
      subject.oer_rates.wont_be_empty
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

    it 'should allow update after save' do
      begin
        subject.refresh_rates
        # rubocop:disable Style/RescueStandardError
      rescue
        # rubocop:enable Style/RescueStandardError
        assert false, 'Should allow updating after saving'
      end
    end

    it 'should not break an existing file if save fails to read' do
      initial_size = File.read(temp_cache_path).size
      subject.stubs(:api_response).returns ''
      subject.refresh_rates
      File.open(temp_cache_path).read.size.must_equal initial_size
    end

    it 'should not break an existing file if save returns json without rates' do
      initial_size = File.read(temp_cache_path).size
      subject.stubs(:api_response).returns '{"error": "An error"}'
      subject.refresh_rates
      File.open(temp_cache_path).read.size.must_equal initial_size
    end

    it 'should not break an existing file if save returns a invalid json' do
      initial_size = File.read(temp_cache_path).size
      subject.stubs(:api_response).returns '{invalid_json: "An error"}'
      subject.refresh_rates
      File.open(temp_cache_path).read.size.must_equal initial_size
    end
  end

  describe '#rates_timestamp' do
    before do
      add_to_webmock(subject)
    end

    it 'should be now when not updated from api' do
      subject.rates_timestamp.must_be :>, Time.at(1_414_008_044)
    end

    it 'should be set on update_rates' do
      subject.update_rates
      subject.rates_timestamp.must_equal Time.at(1_414_008_044)
    end
  end

  describe '#expire_rates' do
    before do
      add_to_webmock(subject)
      # see test/data/latest.json +4
      subject.rates_timestamp = 1_414_008_044
      @ttl_in_seconds = 1000
      subject.ttl_in_seconds = @ttl_in_seconds
      @old_usd_eur_rate = 0.655
      # see test/data/latest.json +52
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
    end

    describe 'when the ttl has expired' do
      it 'should update the rates' do
        Timecop.freeze(subject.rates_timestamp) do
          subject.get_rate('USD', 'EUR').must_equal @old_usd_eur_rate
        end
        Timecop.freeze(subject.rates_timestamp + (@ttl_in_seconds + 1)) do
          subject.get_rate('USD', 'EUR').wont_equal @old_usd_eur_rate
          subject.get_rate('USD', 'EUR').must_equal @new_usd_eur_rate
        end
      end

      it 'should save rates' do
        Timecop.freeze(subject.rates_timestamp) do
          subject.get_rate('USD', 'EUR').must_equal @old_usd_eur_rate
        end
        Timecop.freeze(subject.rates_timestamp + (@ttl_in_seconds + 1)) do
          subject.get_rate('USD', 'EUR').must_equal @new_usd_eur_rate
          @global_rates.wont_be_empty
        end
      end

      it 'updates the next expiration time' do
        Timecop.freeze(subject.rates_timestamp + (@ttl_in_seconds + 1)) do
          exp_time = subject.rates_timestamp + @ttl_in_seconds
          subject.expire_rates
          subject.rates_expiration.must_equal exp_time
        end
      end

      describe '#force_refresh_rate_on_expire' do
        it 'should save rates and force refresh' do
          subject.force_refresh_rate_on_expire = true
          Timecop.freeze(subject.rates_timestamp) do
            subject.get_rate('USD', 'EUR').must_equal @old_usd_eur_rate
          end
          Timecop.freeze(Time.now + 1001) do
            @global_rates = []
            subject.get_rate('USD', 'EUR').must_equal @new_usd_eur_rate
            @global_rates.wont_be_empty
          end
        end
      end
    end

    describe 'when the ttl has not expired' do
      it 'should not update the rates' do
        exp_time = subject.rates_expiration
        Timecop.freeze(subject.rates_timestamp) do
          subject.expects(:update_rates).never
          subject.expects(:refresh_rates_expiration).never
          subject.expire_rates
          subject.rates_expiration.must_equal exp_time
        end
      end
    end
  end

  describe 'historical' do
    before do
      add_to_webmock(subject)
      # see test/latest.json +52
      @latest_usd_eur_rate = 0.79085
      # see test/2015-01-01.json +52
      @old_usd_eur_rate = 0.830151
      subject.update_rates
    end

    it 'should be different than the latest' do
      subject.get_rate('USD', 'EUR').must_equal @latest_usd_eur_rate
      subject.date = '2015-01-01'
      add_to_webmock(subject, oer_historical_path)
      subject.update_rates
      subject.get_rate('USD', 'EUR').must_equal @old_usd_eur_rate
    end
  end

  describe 'source currency' do
    it 'should be changed when a known currency is given' do
      source = 'EUR'
      subject.source = source
      subject.source.must_equal source
      subject.source_url.must_include "base=#{source}"
    end

    it 'should use USD when given unknown currency' do
      source = 'invalid'
      subject.source = source
      subject.source.must_equal default_source
      subject.source_url.wont_include "base=#{default_source}"
    end
  end

  describe 'prettyprint' do
    describe 'when no value given' do
      before do
        subject.prettyprint = nil
      end

      it 'should return the default value' do
        subject.prettyprint.must_equal true
      end

      it 'should include prettyprint param as true' do
        subject.source_url.must_include 'prettyprint=true'
      end
    end

    describe 'when value is given' do
      before do
        subject.prettyprint = false
      end

      it 'should return the value' do
        subject.prettyprint.must_equal false
      end

      it 'should include prettyprint param as false' do
        subject.source_url.must_include 'prettyprint=false'
      end
    end
  end

  describe 'show alternative' do
    describe 'when no value given' do
      before do
        subject.show_alternative = nil
      end

      it 'should return the default value' do
        subject.show_alternative.must_equal false
      end

      it 'should include show_alternative param as false' do
        subject.source_url.must_include 'show_alternative=false'
      end
    end

    describe 'when value is given' do
      before do
        subject.show_alternative = true
      end

      it 'should return the value' do
        subject.show_alternative.must_equal true
      end

      it 'should include show_alternative param as true' do
        subject.source_url.must_include 'show_alternative=true'
      end
    end
  end
end
# rubocop:enable Metrics/BlockLength
