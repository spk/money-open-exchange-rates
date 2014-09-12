# encoding: UTF-8

require File.expand_path(File.join(File.dirname(__FILE__), 'test_helper'))

describe Money::Bank::OpenExchangeRatesBank do
  subject { Money::Bank::OpenExchangeRatesBank.new }

  before do
    @cache_path = File.expand_path(File.join(File.dirname(__FILE__), 'latest.json'))
  end

  describe 'exchange' do
    before do
      subject.app_id = TEST_APP_ID
      @temp_cache_path = File.expand_path(File.join(File.dirname(__FILE__), 'tmp.json'))
      subject.cache = @temp_cache_path
      stub(OpenURI::OpenRead).open(Money::Bank::OpenExchangeRatesBank::OER_URL) { File.read @cache_path }
      subject.save_rates
    end

    it "should be able to exchange a money to its own currency even without rates" do
      money = Money.new(0, "USD")
      subject.exchange_with(money, "USD").must_equal money
    end

    it "should raise if it can't find an exchange rate" do
      money = Money.new(0, "USD")
      proc { subject.exchange_with(money, "AUD") }.must_raise Money::Bank::UnknownRateFormat
    end
  end

  describe 'update_rates' do
    before do
      subject.app_id = TEST_APP_ID
      subject.cache = @cache_path
      subject.update_rates
    end

    it "should update itself with exchange rates from OpenExchangeRates" do
      subject.oer_rates.keys.each do |currency|
        next unless Money::Currency.find(currency)
        subject.get_rate("USD", currency).must_be :>, 0
      end
    end

    it "should return the correct oer rates using oer" do
      subject.oer_rates.keys.each do |currency|
        next unless Money::Currency.find(currency)
        subunit = Money::Currency.wrap(currency).subunit_to_unit
        subject.exchange(100, "USD", currency).cents.
          must_equal((subject.oer_rates[currency].to_f * subunit).round)
      end
    end

    it "should return the correct oer rates using exchange_with" do
      subject.oer_rates.keys.each do |currency|
        next unless Money::Currency.find(currency)
        subunit = Money::Currency.wrap(currency).subunit_to_unit
        subject.exchange_with(Money.new(100, "USD"), currency).cents.
          must_equal((subject.oer_rates[currency].to_f * subunit).round)

        subject.exchange_with(1.to_money("USD"), currency).cents.
          must_equal((subject.oer_rates[currency].to_f * subunit).round)
      end
      subject.exchange_with(5000.to_money('JPY'), 'USD').cents.must_equal 6441
    end

    it "should not return 0 with integer rate" do
      wtf = {
        :priority => 1,
        :iso_code => "WTF",
        :name => "WTF",
        :symbol => "WTF",
        :subunit => "Cent",
        :subunit_to_unit => 1000,
        :separator => ".",
        :delimiter => ","
      }
      Money::Currency.register(wtf)
      subject.add_rate("USD", "WTF", 2)
      subject.exchange_with(5000.to_money('WTF'), 'USD').cents.wont_equal 0
    end

    # in response to #4
    it "should exchange btc" do
      btc = {
        :priority => 1,
        :iso_code => "BTC",
        :name => "Bitcoin",
        :symbol => "BTC",
        :subunit => "Cent",
        :subunit_to_unit => 1000,
        :separator => ".",
        :delimiter => ","
      }
      Money::Currency.register(btc)
      subject.add_rate("USD", "BTC", 1 / 13.7603)
      subject.add_rate("BTC", "USD", 13.7603)
      subject.exchange(100, "BTC", "USD").cents.must_equal 138
    end
  end

  describe 'App ID' do

    before do
      @temp_cache_path = File.expand_path(File.join(File.dirname(__FILE__), 'tmp.json'))
      subject.cache = @temp_cache_path
      stub(OpenURI::OpenRead).open(Money::Bank::OpenExchangeRatesBank::OER_URL) { File.read @cache_path }
    end

    it 'should raise an error if no App ID is set' do
      proc { subject.save_rates }.must_raise Money::Bank::NoAppId
    end

    #TODO: As App IDs are compulsory soon, need to add more tests handle
    # app_id-specific errors from
    # https://openexchangerates.org/documentation#errors
  end

  describe 'no cache' do
    before do
      subject.cache = nil
      subject.app_id = TEST_APP_ID
    end

    it 'should get from url' do
      stub(OpenURI::OpenRead).open(Money::Bank::OpenExchangeRatesBank::OER_URL) { File.read @cache_path }
      subject.update_rates
      subject.oer_rates.wont_be_empty
    end

    it 'should raise an error if invalid path is given to save_rates' do
      proc { subject.save_rates }.must_raise Money::Bank::InvalidCache
    end
  end

  describe 'no valid file for cache' do
    before do
      subject.cache = "space_dir#{rand(999999999)}/out_space_file.json"
      subject.app_id = TEST_APP_ID
    end

    it 'should get from url' do
      stub(OpenURI::OpenRead).open(Money::Bank::OpenExchangeRatesBank::OER_URL) { File.read @cache_path }
      subject.update_rates
      subject.oer_rates.wont_be_empty
    end

    it 'should raise an error if invalid path is given to save_rates' do
      proc { subject.save_rates }.must_raise Money::Bank::InvalidCache
    end
  end

  describe 'using proc for cache' do
    before :each do
      $global_rates = nil
      subject.cache = Proc.new {|v|
        if v
          $global_rates = v
        else
          $global_rates
        end
      }
      subject.app_id = TEST_APP_ID
    end

    it 'should get from url normally' do
      stub(subject).source_url() { @cache_path }
      subject.update_rates
      subject.oer_rates.wont_be_empty
    end

    it 'should save from url and get from cache' do
      stub(subject).source_url { @cache_path }
      subject.save_rates
      $global_rates.wont_be_empty
      dont_allow(subject).source_url
      subject.update_rates
      subject.oer_rates.wont_be_empty
    end

  end

  describe 'save rates' do
    before do
      subject.app_id = TEST_APP_ID
      @temp_cache_path = File.expand_path(File.join(File.dirname(__FILE__), 'tmp.json'))
      subject.cache = @temp_cache_path
      stub(OpenURI::OpenRead).open(Money::Bank::OpenExchangeRatesBank::OER_URL) { File.read @cache_path }
      subject.save_rates
    end

    it 'should allow update after save' do
      begin
        subject.update_rates
      rescue
        assert false, "Should allow updating after saving"
      end
    end

    it "should not break an existing file if save fails to read" do
      initial_size = File.read(@temp_cache_path).size
      stub(subject).read_from_url {""}
      subject.save_rates
      File.open(@temp_cache_path).read.size.must_equal initial_size
    end

    it "should not break an existing file if save returns json without rates" do
      initial_size = File.read(@temp_cache_path).size
      stub(subject).read_from_url { %Q({"error": "An error"}) }
      subject.save_rates
      File.open(@temp_cache_path).read.size.must_equal initial_size
    end

    it "should not break an existing file if save returns a invalid json" do
      initial_size = File.read(@temp_cache_path).size
      stub(subject).read_from_url { %Q({invalid_json: "An error"}) }
      subject.save_rates
      File.open(@temp_cache_path).read.size.must_equal initial_size
    end

    after do
      File.delete @temp_cache_path
    end
  end

  describe 'get rate' do
    LVL_TO_LTL =  5
    USD_TO_RUB = 50
    USD_TO_EUR = 1.3

    before do
      # some kind of stubbing base class
      Money::Bank::VariableExchange.class_eval do
        def get_rate(from, to)
          if from == 'LVL' && to == 'LTL'
            LVL_TO_LTL
          elsif from == 'USD' && to == 'RUB'
            USD_TO_RUB
          elsif from == 'USD' && to == 'EUR'
            USD_TO_EUR
          else
            nil
          end
        end
      end
    end

    it 'returns rate if Money::Bank::VariableExchange#get_rate returns rate' do
      subject.get_rate('LVL','LTL').must_equal LVL_TO_LTL
    end

    describe 'calculate cross rate using "USD" rate value if no data was returned by Money::Bank::VariableExchange#get_rate' do

      it 'returns cross rate if "USD" rates for provided currencies exist' do
        eur_to_rub_cross_rate = USD_TO_RUB / USD_TO_EUR
        subject.get_rate('EUR', 'RUB').must_equal eur_to_rub_cross_rate
      end

      it 'raises Money::Bank::UnknownRateFormat if no cross rates found' do
        proc { subject.get_rate('ZAR', 'ZMK') }.must_raise Money::Bank::UnknownRateFormat
      end
    end
  end

  describe '#expire_rates' do
    before do
      subject.app_id = TEST_APP_ID
      subject.ttl_in_seconds = 1000
      @usd_eur_rate = 0.655
      subject.add_rate('USD', 'EUR', @usd_eur_rate)
      @temp_cache_path = File.expand_path(File.join(File.dirname(__FILE__), 'tmp.json'))
      subject.cache = @temp_cache_path
      stub(OpenURI::OpenRead).open(Money::Bank::OpenExchangeRatesBank::OER_URL) { File.read @cache_path }
    end

    describe 'when the ttl has expired' do
      before do
        new_time = Time.now + 1001
        Timecop.freeze(new_time)
      end

      after do
        Timecop.return
      end

      it 'should update the rates' do
        subject.update_rates
        subject.get_rate('USD', 'EUR').wont_equal @usd_eur_rate
      end

      it 'updates the next expiration time' do
        exp_time = Time.now + 1000

        subject.expire_rates
        subject.rates_expiration.must_equal exp_time
      end
    end

    describe 'when the ttl has not expired' do
      it 'not should update the rates' do
        exp_time = subject.rates_expiration
        subject.expire_rates
        subject.rates_expiration.must_equal exp_time
      end
    end
  end
end
