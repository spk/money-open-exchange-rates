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
      stub(subject).read_from_url { File.read @cache_path }
      subject.save_rates
    end

    after do
      File.unlink(@temp_cache_path)
    end

    describe "without rates" do
      it "should be able to exchange a money to its own currency even without rates" do
        money = Money.new(0, "USD")
        subject.exchange_with(money, "USD").must_equal money
      end

      it "should raise if it can't find an exchange rate" do
        money = Money.new(0, "USD")
        proc { subject.exchange_with(money, "SSP") }.must_raise Money::Bank::UnknownRate
      end
    end

    describe "with rates" do
      before do 
        subject.update_rates
      end

      it "should be able to exchange money from USD to a known exchange rate" do
        money = Money.new(100, "USD")
        subject.exchange_with(money, "BBD").must_equal Money.new(200, 'BBD')
      end

      it "should be able to exchange money from a known exchange rate to USD" do
        money = Money.new(200, "BBD")
        subject.exchange_with(money, "USD").must_equal Money.new(100, 'USD')
      end

      it "should raise if it can't find an exchange rate" do
        money = Money.new(0, "USD")
        proc { subject.exchange_with(money, "SSP") }.must_raise Money::Bank::UnknownRate
      end
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
      subject.add_rate("WTF", "USD", 2)
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
      rate = 13.7603
      subject.add_rate("USD", "BTC", 1 / 13.7603)
      subject.add_rate("BTC", "USD", rate)
      subject.exchange_with(100.to_money("BTC"), 'USD').cents.must_equal 137603
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
