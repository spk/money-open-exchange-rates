# encoding: UTF-8
require 'minitest/autorun'
require 'rr'
require 'money/bank/open_exchange_rates_bank'
require 'monetize/core_extensions'
require 'timecop'
require 'pry'
Money.silence_core_extensions_deprecations = true

TEST_APP_ID_PATH = File.join(File.dirname(__FILE__), '..', 'TEST_APP_ID')
TEST_APP_ID = ENV['TEST_APP_ID'] || File.read(TEST_APP_ID_PATH)

if TEST_APP_ID.nil? || TEST_APP_ID.empty?
  raise "Please add a valid app id to file #{TEST_APP_ID_PATH} or to TEST_APP_ID environment"
end
