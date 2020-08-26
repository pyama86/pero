require 'docker'
require 'digest/md5'
require "retryable"
require 'net/https'
module Pero
  class Docker
    attr_reader :server_version
    def initialize(version, environment)
      @server_version = version
      @environment = environment
    end

    def build
      Pero.log.info "start build container"
      begin
        image = ::Docker::Image.build(docker_file)
      rescue => e
        Pero.log.debug docker_file
        Pero.log.error "failed build container #{e.inspect}"
        raise e
      end
      Pero.log.info "success build container"
      image
    end

    def container_name
      "pero-#{server_version}-#{Digest::MD5.hexdigest(Dir.pwd)[0..5]}-#{@environment}"
    end

    def find
      ::Docker::Container.all(:all => true).find do |c|
        c.info["Names"].first == "/#{container_name}"
      end
    end

    def alerady_run?
      c = find
      c && c.info["State"] != "exited" && c
    end

    def run
      ::Docker::Container.all(:all => true).each do |c|
        c.delete(:force => true) if c.info["Names"].first == "/#{container_name}"
      end

      container = ::Docker::Container.create({
        'name' => container_name,
        'Hostname' => 'puppet',
        'Image' => build.id,
        'ExposedPorts' => { '8140/tcp' => {} },
      })

      Pero.log.info "start puppet master container"
      container.start(
        'Binds' => [
          "#{Dir.pwd}:/etc/puppetlabs/code/environments/#{@environment}",
          "#{Dir.pwd}/keys:/etc/puppetlabs/puppet/eyaml/",
        ],
        'PortBindings' => {
          '8140/tcp' => [{ 'HostPort' => "0" }],
        },
      )

      container = find
      raise "can't start container" unless container
      begin
        Retryable.retryable(tries: 20, sleep: 5) do
          https = Net::HTTP.new('localhost', container.info["Ports"].first["PublicPort"])
          https.use_ssl = true
          https.verify_mode = OpenSSL::SSL::VERIFY_NONE
          Pero.log.debug "start server health check"
          https.start {
            response = https.get('/')
            Pero.log.debug "puppet http response #{response}"
          }
        rescue => e
          Pero.log.debug e.inspect
          raise e
        end
      rescue
        Pero.log.error "can't start container.please check [ docker logs #{container.info["id"]} ]"
        container = find
        container.kill if container && container.info["State"] != "exited"
        raise "can't start puppet server"
      end
      container
    end

    def puppet_config
<<-EOS
[master]
vardir = /var/puppet
certname = puppet
dns_alt_names = puppet,localhost
autosign = true
environment_timeout = unlimited
codedir = /etc/puppetlabs/code

[main]
server = puppet
#{@environment && @environment != "" ? "environment = #{@environment}" : nil}
EOS


    end
    def docker_file
      release_package,package_name, conf_dir  = if Gem::Version.new("4.0.0") > Gem::Version.new(server_version)
        ["puppetlabs-release-el-#{el}.noarch.rpm", "puppet-server", "/etc/puppet"]
      elsif Gem::Version.new("5.0.0") > Gem::Version.new(server_version) && Gem::Version.new("4.0.0") <= Gem::Version.new(server_version)
        ["puppetlabs-release-pc1-el-#{el}.noarch.rpm", "puppetserver", "/etc/puppetlabs/puppet/"]
      elsif Gem::Version.new("6.0.0") > Gem::Version.new(server_version)&& Gem::Version.new("5.0.0") <= Gem::Version.new(server_version)
        ["puppet5-release-el-#{el}.noarch.rpm", "puppetserver", "/etc/puppetlabs/puppet/"]
      else
        ["puppet6-release-el-#{el}.noarch.rpm", "puppetserver", "/etc/puppetlabs/puppet/"]
      end

      <<-EOS
FROM #{from_image}
RUN curl -L -k -O https://yum.puppetlabs.com/#{release_package}  && \
rpm -ivh #{release_package}
RUN yum install -y #{package_name}-#{server_version}
ENV PATH $PATH:/opt/puppetlabs/bin
RUN echo -e "#{puppet_config.split(/\n/).join("\\n")}" > #{conf_dir}/puppet.conf
CMD bash -c "rm -rf #{conf_dir}/ssl/* && #{create_ca} && #{run_cmd}"
      EOS
    end

    def create_ca
      release_package,package_name, conf_dir  = if Gem::Version.new("5.0.0") > Gem::Version.new(server_version)
        'puppet cert generate `hostname` --dns_alt_names localhost,127.0.0.1'
      elsif Gem::Version.new("6.0.0") > Gem::Version.new(server_version)
        'puppet cert generate `hostname` --dns_alt_names localhost,127.0.0.1'
      else
        'puppetserver ca setup --ca-name `hostname` --subject-alt-names DNS:localhost'
      end
    end

    def run_cmd
      release_package,package_name, conf_dir  = if Gem::Version.new("5.0.0") > Gem::Version.new(server_version)
        'puppet master --no-daemonize --verbose'
      elsif Gem::Version.new("6.0.0") > Gem::Version.new(server_version)
        'puppetserver foreground'
      else
        'puppetserver foreground'
      end
    end

    def el
      if Gem::Version.new("3.5.1") > Gem::Version.new(server_version)
        6
      else
        7
      end
    end

    def from_image
      "centos:#{el}"
    end
  end
end
