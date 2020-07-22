# frozen_string_literal: true

require 'rake/testtask'
require 'rubocop/rake_task'

default = %i[test rubocop]
task default: default

Rake::TestTask.new do |t|
  t.pattern = 'test/**/*_test.rb'
end
task spec: :test

desc 'Execute rubocop'
RuboCop::RakeTask.new(:rubocop) do |t|
  t.options = ['--display-cop-names', '--display-style-guide']
  t.fail_on_error = true
end
