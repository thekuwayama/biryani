require 'bundler/gem_tasks'
require 'rspec/core/rake_task'
require 'rubocop/rake_task'

RuboCop::RakeTask.new
RSpec::Core::RakeTask.new(:spec)

desc 'conformance test using h2spec'
RSpec::Core::RakeTask.new(:conformance) do |t|
  t.pattern = 'conformance/server_spec.rb'
  t.rspec_opts = %w[--out /dev/null]
  t.verbose = false
end

task default: %i[rubocop spec]
