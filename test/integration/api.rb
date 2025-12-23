# frozen_string_literal: true

require 'json'
require 'money/bank/open_exchange_rates_bank'

# Money 7.x requires explicit default currency configuration
Money.default_currency = Money::Currency.new('USD')

ERROR_MSG = 'Integration test failed!'
cache_path = '/tmp/latest.json'
to_currency = 'CAD'
app_id = ENV.fetch('OXR_APP_ID', nil)

if app_id.nil? || app_id.empty?
  puts 'OXR_APP_ID env var not set skipping integration tests'
  exit 0
end

begin
  puts 'OXR version', Money::Bank::OpenExchangeRatesBank::VERSION

  oxr = Money::Bank::OpenExchangeRatesBank.new
  oxr.cache = cache_path
  oxr.app_id = app_id
  oxr.update_rates
  oxr.save_rates

  Money.default_bank = oxr

  cad_rate = Money.default_bank.get_rate('USD', to_currency)

  json_to_currency = JSON.parse(File.read(cache_path))['rates'][to_currency]
  puts 'JSON to_currency', json_to_currency
  puts 'Money to_currency', cad_rate
  json_to_currency == cad_rate or raise ERROR_MSG
# rubocop:disable Style/RescueStandardError
rescue
  # rubocop:enable Style/RescueStandardError
  raise ERROR_MSG
end
