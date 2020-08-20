require "pero"
require "thor"

module Pero
  class CLI < Thor
    desc "apply", "puppet apply"
    method_option :noop, aliases: '-n', default: false, type: :boolean
    method_option :tags, default: nil, type: :array
    def apply(name_filter)
      image = Pero::Docker.build("3.3.1")
      container = Pero::Docker.run(image)

      Pero::Puppet.forward_and_apply("127.0.0.1", "vagrant", 2200)
      Pero.log.info "stop puppet master container"
      container.kill
    end

    desc "bootstrap", "bootstrap puppet"
    method_option "bootstrap-version", default: "6.17.0", type: :string
    method_option "ssh-user", aliases: '-x', default: ENV['USER'], type: :string
    method_option :noop, aliases: '-n', default: false, type: :boolean
    method_option :verbose, aliases: '-v', default: false, type: :boolean
    method_option :tags, default: nil, type: :array
    def bootstrap(host)
      Pero::Puppet.install_puppet(host, options["ssh-user"], options["bootstrap-version"], parse_option(options))
    end

    no_commands do
      def parse_option(options)
        ret = ""
        %w(noop verbose).each do |n|
          ret << " --#{n}" if options[n]
        end
        ret << " --tags #{options["tags"].join(",")}" if options["tags"]
      end
    end
  end
end
