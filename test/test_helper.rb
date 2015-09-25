require 'minitest/autorun'
require 'rr'
require 'money/bank/open_exchange_rates_bank'
require 'monetize'
require 'timecop'
require 'pry'

TEST_APP_ID_PATH = File.join(File.dirname(__FILE__), '..', 'TEST_APP_ID')
TEST_APP_ID = ENV['TEST_APP_ID'] || File.read(TEST_APP_ID_PATH)

if TEST_APP_ID.nil? || TEST_APP_ID.empty?
  fail "Please add a valid app id to file #{TEST_APP_ID_PATH} or to " \
    ' TEST_APP_ID environment'
end
