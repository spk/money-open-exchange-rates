# frozen_string_literal: true

version_file = 'lib/open_exchange_rates_bank/version'
require File.expand_path("../#{version_file}", __FILE__)

Gem::Specification.new do |s|
  s.name = 'money-open-exchange-rates'
  s.version = OpenExchangeRatesBank::VERSION
  s.homepage = "http://github.com/spk/#{s.name}"
  s.authors = ['Laurent Arnoud']
  s.email = 'laurent@spkdev.net'
  s.description = 'A gem that calculates the exchange rate using published ' \
                  'rates from open-exchange-rates. Compatible with the money gem.'
  s.summary = 'A gem that calculates the exchange rate using published rates ' \
              'from open-exchange-rates.'
  s.extra_rdoc_files = %w[README.md]
  s.files = Dir['LICENSE', 'README.md', 'History.md', 'Gemfile', 'lib/**/*.rb',
                'test/**/*']
  s.license = 'MIT'
  s.require_paths = ['lib']
  s.required_ruby_version = '>= 3.1'
  s.add_dependency 'money', '~> 7.0'
  s.add_dependency 'ostruct', '~> 0.6'
  s.add_development_dependency 'minitest', '~> 5'
  s.add_development_dependency 'mocha', '~> 1.2'
  s.add_development_dependency 'monetize', '~> 2.0'
  s.add_development_dependency 'rake', '~> 12'
  s.add_development_dependency 'rubocop', '~> 1.69'
  s.add_development_dependency 'timecop', '~> 0.9'
  s.add_development_dependency 'webmock', '~> 3.5'
  s.metadata['rubygems_mfa_required'] = 'true'
end
