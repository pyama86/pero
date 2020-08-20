require "pero"
require "thor"

module Pero
  class CLI < Thor
    desc "apply", "puppet apply"
    method_option "ssh-user", aliases: '-x', default: ENV['USER'], type: :string
    method_option :noop, aliases: '-n', default: false, type: :boolean
    method_option :verbose, aliases: '-v', default: false, type: :boolean
    method_option :tags, default: nil, type: :array
    def apply(name_regexp)
      Pero.log.info "start puppet master container"
      nodes = Pero::History.search(name_regexp)
      return unless nodes
      container = Pero::Puppet.run_container(File.read(".puppet-version")) 
      begin
        nodes.each do |n|
          opt = options.dup
          opt["tags"] ||= n["puppet_options"]["tags"]
          Pero::Puppet.forward_and_apply(
            n["host"],
            options["ssh-user"] == ENV['USER'] ? n["puppet_options"]["ssh-user"] : options["ssh-user"],
            parse_option(opt),
            8140
          )
        end
      rescue => e
        Pero.log.error e.inspect
      ensure
        Pero.log.info "stop puppet master container"
        container.kill
      end
    end

    desc "bootstrap", "bootstrap puppet"
    method_option "puppet-version", default: "6.17.0", type: :string
    method_option "ssh-user", aliases: '-x', default: ENV['USER'], type: :string
    method_option :noop, aliases: '-n', default: false, type: :boolean
    method_option :verbose, aliases: '-v', default: false, type: :boolean
    method_option :tags, default: nil, type: :array
    method_option "node-name", aliases: '-N', default: "", type: :string
    def bootstrap(host)
      File.write(".puppet-version", options["puppet-version"])
      Pero::Puppet.install_puppet(host, options["ssh-user"], options["puppet-version"], parse_option(options))
      hostname = nil
      name = if options["node-name"].empty?
               (::Net::SSH.start(host, options["ssh-user"]) { |ssh| hostname = ssh.exec!("hostname").chomp } && hostname )
             else
               options["node-name"]
             end
      Pero::History::Attribute.new(name, host, options).save
    end

    no_commands do
      def parse_option(options)
        ret = ""
        %w(noop verbose).each do |n|
          ret << " --#{n}" if options[n]
        end
        ret << " --tags #{options["tags"].join(",")}" if options["tags"]
        ret
      end
    end
  end
end
