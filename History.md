
1.3.0 / 2019-01-20
==================

  * Update webmock to 3.5
  * Update rubocop to 0.63
  * Switch from rr to mocha/minitest
  * Add prettyprint option
  * README: add info about tests
  * Remove deprecated secure_connection= option
  * Merge pull request #54 from @LinkUpStudioUA / symbols-doc-link-fix
    * Fix link to filtering by symbols doc
  * Fix bundler to <2 on travis (dropped support Ruby < 2.3)
  * Fix bundler to 1.17.3 (2.0 dropped support Ruby < 2.3)
  * Merge pull request #52 from @thejchap / feature/symbols
    * add support for symbols query param
  * Remove ruby 2.0/2.1 support and fix rubocop offenses
  * Add minitest-focus gem
  * Avoid redefine json_response method

v1.2.2 / 2018-03-31
===================

  * Warn secure_connection= is deprecated
  * More simple code on calc_pair_rate_using_base
  * Increase code coverage on source_url
  * Fix parse error specs on refresh_rates
  * Use Coveralls for coverage
  * Add tests for rates_timestamp issue

v1.2.1 / 2018-03-31
===================

  * Fix rates_timestamp should be now per default

v1.2.0 / 2018-03-31
===================

  * Merge pull request #51 from spk/fix-expire_rates
    * Add force_refresh_rate_on_expire option and use api timestamp
  * README: info currency-exchange

v1.1.1 / 2018-03-30
===================

  * Merge pull request #50 from @v-kolesnikov / fix/avoid-monetize
    * Use `monetize` as a development dependency only

v1.1.0 / 2018-03-28
===================

  * Force refresh when ttl is expire and cache invalid (issue #47)
  * Less strict dependency version for money/monetize

v1.0.2 / 2018-03-27
===================

  * Merge pull request #46 from @cedricpim / fix-float-big-decimal-casting
    * Fix issue with Float casting for BigDecimal

v1.0.1 / 2018-03-25
===================

  * Use BigDecimal instead of Float

v1.0.0 / 2018-03-25
===================

  * Merge pull request #41 from @b-mandelbrot /add-show-alternative
    * Add support for black market and digital currency rates
  * Merge pull request #42 from spk/save-rates-when-ttl-expire
    * Save rates to cache after first fetch and add example with Rails
    * Improve documation about cache and rates ttl
    * Save rates when ttl expire
  * Merge pull request #40 from @Jetbuilt / deprecate-secure_connection
    * Closes #39 - Make all requests over https and deprecate `secure_connection`
  * Support Ruby >= 2.0

v0.7.0 / 2016-10-23
===================

  * Merge pull request #36 from @lautis / drop-json-gem
    * Use bundled JSON instead of gem
  * Better api url tests
  * README https links
  * Fix rubocop offense Style/StringLiterals
  * Improve documentation from inch suggestions
  * Skip integration test when OXR_APP_ID not present
  * Avoid leak of api key in integration tests
  * Update josscrowcroft/open-exchange-rates link
  * More info about OXR
  * Merge pull request #35 from spk/integration-test
    * Better integration test

v0.6.1 / 2016-09-21
===================

  * fix: Ensure correct url for historical api calls
  * fix: Ensure correct url for api calls
  * Add failing test for source_url

v0.6.0 / 2016-09-13
===================

  * Merge pull request #29 from @xsve / pairrates
    * Implemented rate calculation for any pair of currencies via base currency
  * Update travis ruby list
  * Fix usage of URI.join instead of File.join

v0.5.0 / 2016-08-12
===================

  * Changed base api url
  * Fix rubocop to 0.41.2 for Ruby 1.9 support
  * Update rake to 11 and rubocop to 0.41
  * README add Installation
  * Update rubocop to 0.38
  * Always use raise to signal exceptions
  * Use last rubinius binary on travis
  * Update year
  * Update README badges
  * Update jruby to 9.0.4.0
  * Update rubocop and add frozen_string_literal
  * Add Ruby 2.3 and rbx-2 to CI
  * Remove inch from dev tools for ruby 1.9
  * Update money deps
  * Update deps and freeze strings constants

v0.4.1 / 2015-12-06
===================

  * Add more test for latest and historical urls
  * used the correct URL for secure historical

v0.4.0 / 2015-09-28
===================

  * Add webmock helpers for tests
  * No need for TEST_APP_ID with webmock
  * Add ChangeLog
  * Support historical data endpoint with date
  * move version into a module not depending on money
  * Remove encodings headers
  * Better secure_connection tests
  * Better temp_cache_path and read_from_url use on tests
  * Update inch to 0.7
  * Add Money::Bank::OpenExchangeRatesBank::VERSION
  * Update minitest and timecop
  * Use inch for doc suggest
  * Improve doc for #valid_rates?
  * Added jruby-9.0.0.0 to travis
  * Rakefile: add --display-style-guide option to rubocop
  * Improve code documentation
  * Update money gem to 6.6
  * Added license badge
  * Improve code documentation
  * Remove useless doc attr_reader
  * Improve code documentation
  * Improve documentation of OpenExchangeRatesBank class
  * Run rubocop on default rake
  * Added rake rubocop task
  * Added inch documentation badge
  * Rename README.markdown to README.md
  * Update README
  * Add jruby-head to travis
  * Add travis notifications config
  * Make rubocop happy

v0.3.1 / 2015-06-17
===================

  * Fix secure oer url (see #22)
  * Test fail for #22; https
  * More clear spec for ttl (see #17)
  * Add minitest-line for debug
  * Update license date
  * Update license date

v0.3.0 / 2015-06-14
===================

  * add ruby-head to travis.yml
  * gem: syntax check
  * test: syntax check
  * Syntax fix with rubocop
  * Use tr instead of gsub
  * update monetize to 1.3
  * Tests for the secure_connection option
  * Updated README to include secure_connection example
  * Added the secure_connection option to enable HTTPS connections to OER
  * travis: added 2.2.0 version

v0.2.3 / 2014-12-21
===================

  * Bump to 0.2.3
  * Upgrade money to 6.5.0 and monetize to 1.1.0
  * update not present exchange rate and know exchange
  * Update latest.json
  * Doc save_rates and code cleanup
  * adjust tests to intentionally remove AED from data file and test conversions to AED
  * setup reverse rates (ie. XYZ -> USD)
  * travis: cache bundler
  * README: added badges [ci skip]

v0.2.0 / 2014-09-12
===================

  * update contributors and authors
  * travis: remove jruby-head
  * use exchange_with and get_rate from VariableExchange
  * tests: unify raise testing
  * tests: @bank to subject
  * Revert "travis: cache bundle remove 1.9.3,jruby"
  * travis: cache bundle remove 1.9.3,jruby
  * README: update
  * update money gem to 6.2.1
  * travis: added config

v0.1.7 / 2014-04-15
===================

  * Bump to 0.1.7
  * test: expire_rates implementation testing
  * Remove useless boolean return for expire_rates
  * Added pry gem for debug
  * Add the ability to expire rates after a fixed amount of time
  * test: use const for get rate
  * update case description in spec
  * getting rate implementation moved from #exchange_with to own method
  * test: remove deprecation warning about money 6.1.0
  * test: Remove RR deprecation warning
  * Added license on gemspec
  * README: typo

v0.1.5 / 2013-07-11
===================

  * Added Rakefile for tests
  * Merge pull request #10 from weynsee/remove_multi_json
  * use vanilla json instead of multi_json
  * require at least ruby 1.9.2
  * fix failing tests
  * use https protocol for rubygems.org to avoid warnings

v0.1.1 / 2012-10-01
===================

  * Bump to v0.1.1
  * Some cleanup in tests.
  * Use TEST_APP_ID_PATH.
  * Update README for tests and app_id.
  * Refactoring to cope with Proc for cache, allowing greater flexibility
  * Tidy up formatting
  * Added app_id necessary for ongoing usage of OER API

v0.0.7 / 2012-07-23
===================

  * Bump to v0.0.7
  * Added contributors.
  * Update documentation - update_rates must be called prior to attempting a currency conversation
  * Raise unknown rate format if can't find an exchange rate (rather than FloatDomainError)

v0.0.6 / 2012-05-08
===================

  * Added invalid json case for save_rates.
  * Use cache for exchange test and use same_currency?
  * Update spec for money 5.0.0 version.
  * Make sure cache file isn't overwritten if json returns an error
  * Don't error out when exchanging from a currency to itself even if there are no rates
  * Restructure to prevent writing empty cache file, and add spec

v0.0.5 / 2012-03-29
===================

  * Better tests.
  * Fix over issue over integer type rate.
  * overwrite cache file in a block to make sure it's closed after writing
  * add failing test when calling update_rates after save_rates
  * Remove warning: already initialized constant STRINGIFIED_KEYS
  * make tests pass for money 4.0.2
  * round numbers correctly to make tests pass in 1.8.7-p358

v0.0.4 / 2011-12-11
===================

  * Skip exchange unknown by Money and fix tests.
  * Sync latest openexchangerates.

v0.0.3 / 2011-10-19
===================

  * Dont check file exist for a cache...

v0.0.2 / 2011-10-19
===================

  * [bugfix] check file exist on filesystem.
  * Initial commit.
