require File.expand_path(File.join(File.dirname(__FILE__), 'test_helper'))

# rubocop:disable Metrics/BlockLength
describe Money::Bank::OpenExchangeRatesBank do
  subject { Money::Bank::OpenExchangeRatesBank.new }
  let(:oer_url) { Money::Bank::OpenExchangeRatesBank::OER_URL }
  let(:oer_historical_url) do
    Money::Bank::OpenExchangeRatesBank::OER_HISTORICAL_URL
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
      subject.save_rates
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
      proc { subject.save_rates }.must_raise Money::Bank::NoAppId
    end

    # TODO: As App IDs are compulsory soon, need to add more tests handle
    # app_id-specific errors from
    # https://openexchangerates.org/documentation#errors
  end

  describe 'no cache' do
    before do
      subject.cache = nil
      add_to_webmock(subject)
    end

    it 'should get from url' do
      subject.update_rates
      subject.oer_rates.wont_be_empty
    end

    it 'should raise an error if invalid path is given to save_rates' do
      proc { subject.save_rates }.must_raise Money::Bank::InvalidCache
    end
  end

  describe 'secure_connection' do
    before do
      subject.app_id = TEST_APP_ID
    end

    describe 'historical' do
      before do
        subject.date = '2015-01-01'
      end

      let(:historical_url) do
        "#{oer_historical_url}#{subject.date}.json?app_id=#{TEST_APP_ID}"
      end

      it 'should use the secure https url' do
        subject.source_url.must_equal historical_url
        subject.source_url.must_include 'https://'
        subject.source_url.must_include "/api/historical/#{subject.date}.json"
      end
    end

    describe 'latest' do
      it 'should use the secure https url' do
        subject.source_url.must_equal "#{oer_url}?app_id=#{TEST_APP_ID}"
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

    it 'should get from url' do
      subject.update_rates
      subject.oer_rates.wont_be_empty
    end

    it 'should raise an error if invalid path is given to save_rates' do
      proc { subject.save_rates }.must_raise Money::Bank::InvalidCache
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
    end

    it 'should get from url normally' do
      subject.update_rates
      subject.oer_rates.wont_be_empty
    end

    it 'should save from url and get from cache' do
      subject.save_rates
      @global_rates.wont_be_empty
      dont_allow(subject).source_url
      subject.update_rates
      subject.oer_rates.wont_be_empty
    end
  end

  describe 'save rates' do
    before do
      add_to_webmock(subject)
      subject.cache = temp_cache_path
      subject.save_rates
    end

    after do
      File.unlink(temp_cache_path)
    end

    it 'should allow update after save' do
      begin
        subject.update_rates
      rescue
        assert false, 'Should allow updating after saving'
      end
    end

    it 'should not break an existing file if save fails to read' do
      initial_size = File.read(temp_cache_path).size
      stub(subject).read_from_url { '' }
      subject.save_rates
      File.open(temp_cache_path).read.size.must_equal initial_size
    end

    it 'should not break an existing file if save returns json without rates' do
      initial_size = File.read(temp_cache_path).size
      stub(subject).read_from_url { '{"error": "An error"}' }
      subject.save_rates
      File.open(temp_cache_path).read.size.must_equal initial_size
    end

    it 'should not break an existing file if save returns a invalid json' do
      initial_size = File.read(temp_cache_path).size
      stub(subject).read_from_url { '{invalid_json: "An error"}' }
      subject.save_rates
      File.open(temp_cache_path).read.size.must_equal initial_size
    end
  end

  describe '#expire_rates' do
    before do
      add_to_webmock(subject)
      subject.ttl_in_seconds = 1000
      @old_usd_eur_rate = 0.655
      # see test/latest.json +52
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
        subject.get_rate('USD', 'EUR').must_equal @old_usd_eur_rate
        Timecop.freeze(Time.now + 1001) do
          subject.get_rate('USD', 'EUR').wont_equal @old_usd_eur_rate
          subject.get_rate('USD', 'EUR').must_equal @new_usd_eur_rate
        end
      end

      it 'should save rates' do
        subject.get_rate('USD', 'EUR').must_equal @old_usd_eur_rate
        Timecop.freeze(Time.now + 1001) do
          subject.get_rate('USD', 'EUR').must_equal @new_usd_eur_rate
          @global_rates.wont_be_empty
        end
      end

      it 'updates the next expiration time' do
        Timecop.freeze(Time.now + 1001) do
          exp_time = Time.now + 1000
          subject.expire_rates
          subject.rates_expiration.must_equal exp_time
        end
      end
    end

    describe 'when the ttl has not expired' do
      it 'not should update the rates' do
        exp_time = subject.rates_expiration
        dont_allow(subject).update_rates
        dont_allow(subject).save_rates
        dont_allow(subject).refresh_rates_expiration
        subject.expire_rates
        subject.rates_expiration.must_equal exp_time
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
      subject.source = 'EUR'
      subject.source.must_equal 'EUR'
    end

    it 'should use USD when given unknown currency' do
      subject.source = 'invalid'
      subject.source.must_equal 'USD'
    end
  end
end
