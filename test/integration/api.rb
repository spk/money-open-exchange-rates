require 'json'
require 'money/bank/open_exchange_rates_bank'

ERROR_MSG = 'Integration test failed!'.freeze

puts 'OXR version', Money::Bank::OpenExchangeRatesBank::VERSION

cache_path = '/tmp/latest.json'
to_currency = 'CAD'
oxr = Money::Bank::OpenExchangeRatesBank.new
oxr.cache = cache_path
oxr.app_id = ENV['OXR_APP_ID']
oxr.update_rates

Money.default_bank = oxr

cad_rate = Money.default_bank.get_rate('USD', to_currency)

begin
  oxr.save_rates
  json_to_currency = JSON.parse(File.read(cache_path))['rates'][to_currency]
  puts 'JSON to_currency', json_to_currency
  puts 'Money to_currency', cad_rate
  # rubocop:disable Style/AndOr
  json_to_currency == cad_rate or raise ERROR_MSG
rescue
  raise ERROR_MSG
end
