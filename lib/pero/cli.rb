require "pero"
require "thor"
require "parallel"

module Pero
  class CLI < Thor
    class << self
      def exit_on_failure?
        true
      end
    end

    def initialize(*)
      super
      Pero.log.level = ::Logger.const_get(options[:log_level].upcase) if options[:log_level]
    end

    def self.shared_options
      option :log_level, type: :string, aliases: ['-l'], default: 'info'
      option :user, type: :string, aliases: ['-x']
      option :key, type: :string, aliases: ['-i']
      option :port, type: :numeric, aliases: ['-p']
      option :ssh_config, type: :string
      option :environment, type: :string
      option :ask_password, type: :boolean, default: false
      option :vagrant, type: :boolean, default: false
      option :sudo, type: :boolean, default: true
      option "currency", aliases: '-N',default: 3, type: :numeric
    end

    desc "versions", "show support version"
    def versions
      Pero::Docker.show_versions
    end

    desc "apply", "puppet apply"
    shared_options
    option "server-version", type: :string, default: "6.12.0"
    option :noop, aliases: '-n', default: false, type: :boolean
    option :verbose, aliases: '-v', default: true, type: :boolean
    option :tags, default: nil, type: :array
    def apply(name_regexp)
      nodes = Pero::History.search(name_regexp)
      return unless nodes
      Parallel.each(nodes, in_process: options["currency"]) do |n|
        opt = n["last_options"].merge(options)
        puppet = Pero::Puppet.new(opt["host"], opt)
        puppet.apply
      end
    end

    desc "install", "install puppet"
    shared_options
    option "agent-version", default: "6.17.0", type: :string
    option "node-name", aliases: '-N', default: "", type: :string
    def install(*hosts)
      Parallel.each(hosts, in_process: options["currency"]) do |host|
        next if host =~ /^-/
        puppet = Pero::Puppet.new(host, options)
        puppet.install
      end
    end
  end
end
