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
      option :user, type: :string, aliases: ['-x'], desc: "ssh user"
      option :key, type: :string, aliases: ['-i'], desc: "ssh private key"
      option :port, type: :numeric, aliases: ['-p'], desc: "ssh port"
      option :ssh_config, type: :string, desc: "ssh config path"
      option :environment, type: :string, desc: "puppet environment"
      option :ask_password, type: :boolean, default: false, desc: "ask ssh or sudo password"
      option :vagrant, type: :boolean, default: false, desc: "use vagrarant"
      option :sudo, type: :boolean, default: true, desc: "use sudo"
      option "concurrent", aliases: '-C',default: 3, type: :numeric, desc: "running concurrent"
    end

    desc "versions", "show support version"
    def versions
      begin
        Pero::Puppet::Redhat.show_versions
      rescue => e
        Pero.log.error e.inspect
      end
    end

    desc "apply", "puppet apply"
    shared_options
    option "server-version", type: :string, default: "6.12.0"
    option :noop, aliases: '-n', default: false, type: :boolean
    option :verbose, aliases: '-v', default: true, type: :boolean
    option :tags, default: nil, type: :array
    option "one-shot", default: false, type: :boolean, desc: "stop puppet server after run"
    def apply(name_regexp)
      begin
        prepare
        nodes = Pero::History.search(name_regexp)
        return unless nodes
        Parallel.each(nodes, in_process: options["concurrent"]) do |n|
          opt = n["last_options"].merge(options)
          puppet = Pero::Puppet.new(opt["host"], opt)
          puppet.apply
        end
      rescue => e
        Pero.log.error e.inspect
      end
    end

    desc "bootstrap", "bootstrap pero"
    shared_options
    option "agent-version", type: :string
    option "node-name", aliases: '-N', default: "", type: :string, desc: "json node name(default hostname)"
    def bootstrap(*hosts)
      begin
        Parallel.each(hosts, in_process: options["concurrent"]) do |host|
          next if host =~ /^-/
          puppet = Pero::Puppet.new(host, options)
          puppet.install
        end
      rescue => e
        Pero.log.error e.inspect
      end
    end

    no_commands do
      def prepare
        `bundle insatll` if File.exists?("Gemfile")
        `bundle exec librarian-puppet install` if File.exists?("Puppetfile")
      end
    end
  end
end
