# frozen_string_literal: true

require 'minitest/autorun'
require 'webmock/minitest'
require_relative '../../../lib/money/bank/open_exchange_rates_bank'

class OpenExchangeRatesBankBidAskTest < Minitest::Test
  def setup
    @bank = Money::Bank::OpenExchangeRatesBank.new
    @bank.app_id = 'test_app_id'
    @bank.fetch_bid_ask_rates = true # Enable bid/ask rates fetching
  end

  def test_direct_store_access
    @bank.store.add_rate('USD', 'EUR_bid', 0.898) # Assuming add_rate is available and correct
    assert_equal 0.898, @bank.store.get_rate('USD', 'EUR_bid'), 'Direct store access failed for EUR_bid'
  end

  def test_handles_missing_bid_ask_in_response
    json_response = {
      rates: {
        "USD": { rate: 1.0 },
        "EUR": { rate: 0.9 }
      },
      timestamp: Time.now.to_i
    }.to_json

    stub_request(:get, 'https://openexchangerates.org/api/latest.json?app_id=test_app_id&prettyprint=true&show_alternative=false&symbols=')
      .to_return(status: 200, body: json_response)

    @bank.update_rates

    assert_raises(Money::Bank::NoRateError) { @bank.get_rate('USD', 'EUR', rate_type: :bid) }
    assert_raises(Money::Bank::NoRateError) { @bank.get_rate('USD', 'EUR', rate_type: :ask) }
  end
end
