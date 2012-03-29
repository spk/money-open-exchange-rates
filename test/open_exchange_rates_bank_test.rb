# encoding: UTF-8

require File.expand_path(File.join(File.dirname(__FILE__), 'test_helper'))

describe Money::Bank::OpenExchangeRatesBank do

  describe 'update_rates' do
    before do
      @cache_path = File.expand_path(File.join(File.dirname(__FILE__), 'latest.json'))
      @bank = Money::Bank::OpenExchangeRatesBank.new
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
      @bank.update_rates
      @bank.oer_rates.keys.each do |currency|
        next unless Money::Currency.find(currency)
        subunit = Money::Currency.wrap(currency).subunit_to_unit
        @bank.exchange(100, "USD", currency).cents.must_equal((@bank.oer_rates[currency].to_f * subunit).round)
      end
    end

    it "should return the correct oer rates using exchange_with" do
      @bank.update_rates
      @bank.oer_rates.keys.each do |currency|
        next unless Money::Currency.find(currency)
        subunit = Money::Currency.wrap(currency).subunit_to_unit
        @bank.exchange_with(Money.new(100, "USD"), currency).cents.must_equal((@bank.oer_rates[currency].to_f * subunit).round)
        @bank.exchange_with(1.to_money("USD"), currency).cents.must_equal((@bank.oer_rates[currency].to_f * subunit).round)
      end
      @bank.exchange_with(5000.to_money('JPY'), 'USD').cents.must_equal 6441
    end

    it "should not return 0 with integer rate" do
      @bank.update_rates
      @bank.exchange_with(5000.to_money('BBD'), 'USD').cents.wont_equal 0
    end

    # in response to #4
    it "should exchange btc" do
      Money::Currency::TABLE[:btc] = {
        :priority => 1,
        :iso_code => "BTC",
        :name => "Bitcoin",
        :symbol => "BTC",
        :subunit => "Cent",
        :subunit_to_unit => 1000,
        :separator => ".",
        :delimiter => ","
      }
      Money::Currency::STRINGIFIED_KEYS << 'btc'
      @bank.add_rate("USD", "BTC", 1 / 13.7603)
      @bank.add_rate("BTC", "USD", 13.7603)
      @bank.exchange(100, "BTC", "USD").cents.must_equal 138
    end
  end

  describe 'no cache' do
    include RR::Adapters::TestUnit

    before do
      @bank = Money::Bank::OpenExchangeRatesBank.new
      @bank.cache = nil
    end

    it 'should get from url' do
      stub(OpenURI::OpenRead).open(Money::Bank::OpenExchangeRatesBank::OER_URL) { File.read @cache_path }
      @bank.update_rates
      @bank.rates_source.must_equal Money::Bank::OpenExchangeRatesBank::OER_URL
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
    end

    it 'should get from url' do
      stub(OpenURI::OpenRead).open(Money::Bank::OpenExchangeRatesBank::OER_URL) { File.read @cache_path }
      @bank.update_rates
      @bank.rates_source.must_equal Money::Bank::OpenExchangeRatesBank::OER_URL
    end

    it 'should raise an error if invalid path is given to save_rates' do
      proc { @bank.save_rates }.must_raise Money::Bank::InvalidCache
    end
  end

  describe 'save rates' do
    include RR::Adapters::TestUnit

    before do
      @bank = Money::Bank::OpenExchangeRatesBank.new
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

    after do
      File.delete @temp_cache_path
    end
  end
end
