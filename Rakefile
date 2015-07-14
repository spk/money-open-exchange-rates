require 'rake/testtask'
require 'rubocop/rake_task'

task default: [:test]

Rake::TestTask.new do |t|
  t.pattern = 'test/**/*_test.rb'
end
task spec: :test

desc 'Execute rubocop'
RuboCop::RakeTask.new(:rubocop) do |t|
  t.options = ['-D'] # display cop name
end
