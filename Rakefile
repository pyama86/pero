require "bundler/gem_tasks"
require "rspec/core/rake_task"

RSpec::Core::RakeTask.new(:spec)

task :default => :spec

task :build_docker do
  puts `docker build -f ./misc/Dockerfile -t pyama/puppet:3.0.1 .`
  puts `docker push pyama/puppet:3.0.1`
end
