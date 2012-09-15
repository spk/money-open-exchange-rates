# encoding: UTF-8

TEST_APP_ID = ENV['TEST_APP_ID'] || File.read(File.join(File.dirname(__FILE__), '../TEST_APP_ID'))
raise "Please add a valid app id to file #{File.dirname(__FILE__)}/../TEST_APP_ID or to TEST_APP_ID environment" if TEST_APP_ID.nil? || TEST_APP_ID == ""

require File.expand_path(File.join(File.dirname(__FILE__), 'test_helper'))

describe Money::Bank::OpenExchangeRatesBank do

  before do
    @cache_path = File.expand_path(File.join(File.dirname(__FILE__), 'latest.json'))
  end

  describe 'exchange' do
    include RR::Adapters::TestUnit

    before do
      @bank = Money::Bank::OpenExchangeRatesBank.new
      @bank.app_id = TEST_APP_ID
      @temp_cache_path = File.expand_path(File.join(File.dirname(__FILE__), 'tmp.json'))
      @bank.cache = @temp_cache_path
      stub(OpenURI::OpenRead).open(Money::Bank::OpenExchangeRatesBank::OER_URL) { File.read @cache_path }
      @bank.save_rates
    end

    it "should be able to exchange a money to its own currency even without rates" do
      money = Money.new(0, "USD");
      @bank.exchange_with(money, "USD").must_equal money
    end

    it "should raise if it can't find an exchange rate" do
      money = Money.new(0, "USD");
      assert_raises(Money::Bank::UnknownRateFormat){ @bank.exchange_with(money, "AUD") }
    end
  end

  describe 'update_rates' do
    before do
      @bank = Money::Bank::OpenExchangeRatesBank.new
      @bank.app_id = TEST_APP_ID
      @bank.cache = @cache_path
      @bank.update_rates
    end

    it "should update itself with exchange rates from OpenExchangeRates" do
      @bank.oer_rates.keys.each do |currency|
        next unless Money::Currency.find(currency)
        @bank.get_rate("USD", currency).must_be :>, 0
      end
    end

    it "should return the correct oer rates using oer" do
      @bank.oer_rates.keys.each do |currency|
        next unless Money::Currency.find(currency)
        subunit = Money::Currency.wrap(currency).subunit_to_unit
        @bank.exchange(100, "USD", currency).cents.must_equal((@bank.oer_rates[currency].to_f * subunit).round)
      end
    end

    it "should return the correct oer rates using exchange_with" do
      @bank.oer_rates.keys.each do |currency|
        next unless Money::Currency.find(currency)
        subunit = Money::Currency.wrap(currency).subunit_to_unit
        @bank.exchange_with(Money.new(100, "USD"), currency).cents.must_equal((@bank.oer_rates[currency].to_f * subunit).round)
        @bank.exchange_with(1.to_money("USD"), currency).cents.must_equal((@bank.oer_rates[currency].to_f * subunit).round)
      end
      @bank.exchange_with(5000.to_money('JPY'), 'USD').cents.must_equal 6441
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
      @bank.add_rate("USD", "WTF", 2)
      @bank.exchange_with(5000.to_money('WTF'), 'USD').cents.wont_equal 0
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
      @bank.add_rate("USD", "BTC", 1 / 13.7603)
      @bank.add_rate("BTC", "USD", 13.7603)
      @bank.exchange(100, "BTC", "USD").cents.must_equal 138
    end
  end

begin
  describe 'App ID' do
    include RR::Adapters::TestUnit
    
    before do
      @bank = Money::Bank::OpenExchangeRatesBank.new
      @temp_cache_path = File.expand_path(File.join(File.dirname(__FILE__), 'tmp.json'))
      @bank.cache = @temp_cache_path
      stub(OpenURI::OpenRead).open(Money::Bank::OpenExchangeRatesBank::OER_URL) { File.read @cache_path }
    end
    
    it 'should raise an error if no App ID is set' do
      proc {@bank.save_rates}.must_raise Money::Bank::NoAppId
    end
    
    #TODO: As App IDs are compulsory soon, need to add more tests handle app_id-specific errors from https://openexchangerates.org/documentation#errors    
  end
end

  describe 'no cache' do
    include RR::Adapters::TestUnit

    before do
      @bank = Money::Bank::OpenExchangeRatesBank.new
      @bank.cache = nil
      @bank.app_id = TEST_APP_ID
    end

    it 'should get from url' do
      stub(OpenURI::OpenRead).open(Money::Bank::OpenExchangeRatesBank::OER_URL) { File.read @cache_path }
      @bank.update_rates
      @bank.oer_rates.wont_be_empty
    end

    it 'should raise an error if invalid path is given to save_rates' do
      proc { @bank.save_rates }.must_raise Money::Bank::InvalidCache
    end
  end

  describe 'no valid file for cache' do
    include RR::Adapters::TestUnit
    before do
      @bank = Money::Bank::OpenExchangeRatesBank.new
      @bank.cache = "space_dir#{rand(999999999)}/out_space_file.json"
      @bank.app_id = TEST_APP_ID
    end

    it 'should get from url' do
      stub(OpenURI::OpenRead).open(Money::Bank::OpenExchangeRatesBank::OER_URL) { File.read @cache_path }
      @bank.update_rates
      @bank.oer_rates.wont_be_empty
    end

    it 'should raise an error if invalid path is given to save_rates' do
      proc { @bank.save_rates }.must_raise Money::Bank::InvalidCache
    end
  end

  describe 'using proc for cache' do
    include RR::Adapters::TestUnit

    before :each do
      $global_rates = nil
      @bank = Money::Bank::OpenExchangeRatesBank.new
      @bank.cache = Proc.new {|v|
        if v
          $global_rates = v
        else
          $global_rates
        end
      }
      @bank.app_id = TEST_APP_ID
    end

    it 'should get from url normally' do
      stub(@bank).source_url() { @cache_path }
      @bank.update_rates
      @bank.oer_rates.wont_be_empty
    end

    it 'should save from url and get from cache' do
      stub(@bank).source_url { @cache_path }
      @bank.save_rates
      $global_rates.wont_be_empty
      dont_allow(@bank).source_url
      @bank.update_rates
      @bank.oer_rates.wont_be_empty
    end

  end

  describe 'save rates' do
    include RR::Adapters::TestUnit

    before do
      @bank = Money::Bank::OpenExchangeRatesBank.new
      @bank.app_id = "temp-e091fc14b3884a516d6cc2c299a"
      @temp_cache_path = File.expand_path(File.join(File.dirname(__FILE__), 'tmp.json'))
      @bank.cache = @temp_cache_path
      stub(OpenURI::OpenRead).open(Money::Bank::OpenExchangeRatesBank::OER_URL) { File.read @cache_path }
      @bank.save_rates
    end

    it 'should allow update after save' do
      begin
        @bank.update_rates
      rescue
        assert false, "Should allow updating after saving"
      end
    end

    it "should not break an existing file if save fails to read" do
      initial_size = File.read(@temp_cache_path).size
      stub(@bank).read_from_url {""}
      @bank.save_rates
      File.open(@temp_cache_path).read.size.must_equal initial_size
    end

    it "should not break an existing file if save returns json without rates" do
      initial_size = File.read(@temp_cache_path).size
      stub(@bank).read_from_url { %Q({"error": "An error"}) }
      @bank.save_rates
      File.open(@temp_cache_path).read.size.must_equal initial_size
    end

    it "should not break an existing file if save returns a invalid json" do
      initial_size = File.read(@temp_cache_path).size
      stub(@bank).read_from_url { %Q({invalid_json: "An error"}) }
      @bank.save_rates
      File.open(@temp_cache_path).read.size.must_equal initial_size
    end

    after do
      File.delete @temp_cache_path
    end
  end
end
