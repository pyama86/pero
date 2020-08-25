require 'net/ssh'

Specinfra::Configuration.error_on_missing_backend_type = false
Specinfra.configuration.backend = :ssh
module Specinfra
  module Configuration
    def self.sudo_password
      return ENV['SUDO_PASSWORD'] if ENV['SUDO_PASSWORD']
      return @sudo_password if defined?(@sudo_password)

      # TODO: Fix this dirty hack
      return nil unless caller.any? {|call| call.include?('channel_data') }

      print "sudo password: "
      @sudo_password = STDIN.noecho(&:gets).strip
      print "\n"
      @sudo_password
    end
  end
end

module Pero
  class Puppet
    extend Pero::SshExecutable
    attr_reader :specinfra
    def initialize(host, options)
      @options = options.dup

      @options[:host] = host
      so = ssh_options
      @specinfra = Specinfra::Backend::Ssh.new(
        request_pty: true,
        host: so[:host_name],
        ssh_options: so,
        disable_sudo: false,
      )
    end

    # refs: github.com/itamae-kitchen/itamae
    def ssh_options
      opts = {}
      opts[:host_name] = @options[:host]

      # from ssh-config
      ssh_config_files = @options["ssh_config"] ? [@options["ssh_config"]] : Net::SSH::Config.default_files
      opts.merge!(Net::SSH::Config.for(@options["host"], ssh_config_files))
      opts[:user] = @options["user"] || opts[:user] || Etc.getlogin
      opts[:password] = @options["password"] if @options["password"]
      opts[:keys] = [@options["key"]] if @options["key"]
      opts[:port] = @options["port"] if @options["port"]

      if @options["vagrant"]
        config = Tempfile.new('', Dir.tmpdir)
        hostname = opts[:host_name] || 'default'
        vagrant_cmd = "vagrant ssh-config #{hostname} > #{config.path}"
        if defined?(Bundler)
          Bundler.with_clean_env do
            `#{vagrant_cmd}`
          end
        else
          `#{vagrant_cmd}`
        end
        opts.merge!(Net::SSH::Config.for(hostname, [config.path]))
      end

      if @options["ask_password"]
        print "password: "
        password = STDIN.noecho(&:gets).strip
        print "\n"
        opts.merge!(password: password)
      end
      opts
    end

    def install
      Pero.log.info "bootstrap puppet"
      osi = specinfra.os_info
      os = case osi[:family]
      when "redhat"
        Redhat.new(specinfra, osi)
      else
          raise "sorry unsupport os, please pull request!!!"
      end
      os.install(@options["agent-version"])
      Pero::History::Attribute.new(specinfra, @options).save
    end

    def serve_master
        Pero.log.info "start puppet master container"
        container = run_container
        begin
          yield container
        rescue => e
          Pero.log.error e.inspect
          raise e
        ensure
          if @options["one-shot"]
            Pero.log.info "stop puppet master container"
            container.kill
          end
        end
    end

    def run_container
      docker = Pero::Docker.new(@options["server-version"], @options["environment"])
      docker.alerady_run? || docker.run
    end

    def apply
      serve_master do |container|
        port = container.info["Ports"].first["PublicPort"]
        begin
          tmpdir=container.info["id"][0..5]
          Pero.log.info "start forwarding port:#{port}"

          in_ssh_forwarding(port) do |host, ssh|
            Pero.log.info "#{host}:puppet cmd[#{puppet_cmd}]"
            cmd = "mkdir -p /tmp/puppet/#{tmpdir} && unshare -m -- /bin/bash -c 'export PATH=$PATH:/opt/puppetlabs/bin/ && \
                           mkdir -p `puppet config print ssldir` && mount --bind /tmp/puppet/#{tmpdir} `puppet config print ssldir` && \
                           #{puppet_cmd}'"
            Pero.log.debug "run cmd:#{cmd}"
            ssh.exec!(specinfra.build_command(cmd))  do |channel, stream, data|
                             Pero.log.info "#{host}:#{data.chomp}" if stream == :stdout && data.chomp != ""
                             Pero.log.warn "#{host}:#{data.chomp}" if stream == :stderr && data.chomp != ""
                           end
            ssh.loop {true} if ENV['PERO_DEBUG']
          end
        rescue => e
          Pero.log.error "puppet apply error:#{e.inspect}"
        end
      end

      Pero::History::Attribute.new(specinfra, @options).save
    end

    def puppet_cmd
        if Gem::Version.new("5.0.0") > Gem::Version.new(@options["agent-version"])
            "puppet agent --no-daemonize --onetime #{parse_puppet_option(@options)} --server localhost"
        else
            "/opt/puppetlabs/bin/puppet agent --no-daemonize --onetime #{parse_puppet_option(@options)} --server localhost"
        end
    end

    def parse_puppet_option(options)
      ret = ""
      %w(noop verbose).each do |n|
        ret << " --#{n}" if options[n]
      end
      ret << " --tags #{options["tags"].join(",")}" if options["tags"]
      ret
    end

    def in_ssh_forwarding(port)
      options = specinfra.get_config(:ssh_options)

      if !Net::SSH::VALID_OPTIONS.include?(:strict_host_key_checking)
        options.delete(:strict_host_key_checking)
      end

      Net::SSH.start(
        specinfra.get_config(:host),
        options[:user],
        options
      ) do |ssh|
        ssh.forward.remote(port, 'localhost', 8140)
        yield specinfra.get_config(:host), ssh
      end
    end
  end
end
