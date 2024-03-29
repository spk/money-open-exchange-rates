# frozen_string_literal: true

begin
  require 'simplecov'
  SimpleCov.start
rescue LoadError
  warn 'simplecov not loaded'
end

require 'minitest/unit'
require 'minitest/autorun'
require 'mocha/minitest'
require 'webmock/minitest'
require 'money/bank/open_exchange_rates_bank'
require 'monetize'
require 'timecop'

TEST_APP_ID = 'TEST_APP_ID'

def data_file(file)
  File.expand_path(File.join(File.dirname(__FILE__), 'data', file))
end

def add_to_webmock(subject, body_path = oer_latest_path)
  subject.app_id = TEST_APP_ID
  stub_request(:get, subject.source_url)
    .to_return(status: 200, body: File.read(body_path))
end
