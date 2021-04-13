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
      option "timeout", default: 10, type: :numeric, desc: "ssh connect timeout"
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
    option "server-version", type: :string
    option "image-name", type: :string
    option :noop, aliases: '-n', default: false, type: :boolean
    option :test, aliases: '-t', default: false, type: :boolean
    option :verbose, aliases: '-v', default: true, type: :boolean
    option :tags, default: nil, type: :array
    option :volumes, default: nil, type: :array
    option "one-shot", default: false, type: :boolean, desc: "stop puppet server after run"
    def apply(name_regexp)

      if !options["image-name"] && !options["server-version"]
        Pero.log.error "image-name or server-version are required"
        return
      end

      prepare
      nodes = Pero::History.search(name_regexp)
      return unless nodes
      begin
        Parallel.each(nodes, in_process: options["concurrent"]) do |n|
          opt = merge_options(n, options)
          puppet = Pero::Puppet.new(opt["host"], opt)
          puppet.apply
        end
      rescue => e
        Pero.log.error e.backtrace.join("\n")
        Pero.log.error e.inspect

      ensure
        if options["one-shot"]
          Pero.log.info "stop puppet master container"
          Parallel.each(nodes, in_process: options["concurrent"]) do |n|
            opt = merge_options(n, options)
            Pero::Puppet.new(opt["host"], opt).stop_server
          end
        else
          Pero.log.info "puppet master container keep running"
        end
      end
    end

    desc "bootstrap", "bootstrap pero"
    shared_options
    option "agent-version", type: :string
    option "node-name", aliases: '-N', default: "", type: :string, desc: "json node name(default hostname)"
    def bootstrap(*hosts)
      begin
        options["environment"] = "production" if options["environment"].nil? || options["environment"].empty?
        Parallel.each(hosts, in_process: options["concurrent"]) do |host|
          raise "unknown option #{host}" if host =~ /^-/
          puppet = Pero::Puppet.new(host, options)

          Pero.log.info "bootstrap pero #{host}"
          puppet.install
        end
      rescue => e
        Pero.log.error e.backtrace.join("\n")
        Pero.log.error e.inspect
      end
    end

    no_commands do
      def merge_options(node, options)
        opt = node["last_options"].merge(options)
        opt["environment"] = "production" if opt["environment"].nil? || opt["environment"].empty?
        if options["image-name"]
          opt.delete("server-version")
        else
          opt.delete("image-name")
        end
        opt
      end

      def prepare
        `bundle install` if File.exists?("Gemfile")
        `bundle exec librarian-puppet install` if File.exists?("Puppetfile")
      end
    end
  end
end
