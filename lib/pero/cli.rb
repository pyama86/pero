require "pero"
require "thor"
require "parallel"

module Pero
  class CLI < Thor
    def initialize(*)
      super
      Pero.log.level = ::Logger.const_get(options[:log_level].upcase) if options[:log_level]
    end

    def self.define_exec_options
      option :log_level, type: :string, aliases: ['-l'], default: 'info'
      option :user, type: :string, aliases: ['-x']
      option :key, type: :string, aliases: ['-i']
      option :port, type: :numeric, aliases: ['-p']
      option :ssh_config, type: :string
      option :ask_password, type: :boolean, default: false
      option :vagrant, type: :boolean, default: false
      option :sudo, type: :boolean, default: true
      option :noop, aliases: '-n', default: false, type: :boolean
      option :verbose, aliases: '-v', default: false, type: :boolean
      option :tags, default: nil, type: :array
    end

    desc "apply", "puppet apply"
    define_exec_options
    method_option "currency", aliases: '-N',default: 3, type: :numeric
    def apply(name_regexp)
      nodes = Pero::History.search(name_regexp)
      return unless nodes
      Parallel.each(nodes, in_process: options["currency"]) do |n|
        opt = n["last_options"].merge(options)
        puppet = Pero::Puppet.new(opt["host"], opt)
        puppet.apply
      end
    end

    desc "bootstrap", "bootstrap puppet"
    define_exec_options
    method_option "server-version", default: "6.12.1", type: :string
    method_option "agent-version", default: "6.17.0", type: :string
    method_option "node-name", aliases: '-N', default: "", type: :string
    def bootstrap(host)
      puppet = Pero::Puppet.new(host, options)
      puppet.install
      puppet.apply
    end
  end
end
