require 'rake/testtask'
require 'rubocop/rake_task'
require 'inch/rake'

task default: [:test, :rubocop, 'doc:suggest']

Rake::TestTask.new do |t|
  t.pattern = 'test/**/*_test.rb'
end
task spec: :test

desc 'Execute rubocop'
RuboCop::RakeTask.new(:rubocop) do |t|
  t.options = ['--display-cop-names', '--display-style-guide']
  t.fail_on_error = true
end

Inch::Rake::Suggest.new('doc:suggest') do |suggest|
  suggest.args << '--private'
end
