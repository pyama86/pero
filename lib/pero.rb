require "logger"
require "pero/version"
require "pero/cli"
require "pero/puppet/docker"


module Pero
  def self.log
    @log ||= Logger.new(STDOUT)
  end
  class Error < StandardError; end
  # Your code goes here...
end
