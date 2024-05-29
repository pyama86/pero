require "logger"
require "specinfra"
require "pero/version"
require "pero/cli"
require "pero/history"
require "pero/ssh_executable"
require "pero/docker"
require "pero/puppet"
require "pero/puppet/base"
require "pero/puppet/redhat"
require "pero/puppet/ubuntu"


module Pero
  def self.log
    @log ||= Logger.new(STDOUT)
  end
  class Error < StandardError; end
  # Your code goes here...
end
