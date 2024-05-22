require 'docker'
require 'digest/md5'
require 'retryable'
require 'net/https'
module Pero
  class Docker
    attr_reader :server_version, :image_name, :volumes

    def initialize(version, image_name, environment, volumes)
      @server_version = version
      @image_name = image_name
      @environment = environment
      @volumes = volumes
    end

    def build
      Pero.log.info 'start build container'
      ::Docker.options[:read_timeout] = 300
      begin
        image = if image_name
                  ::Docker::Image.create('fromImage' => image_name)
                else
                  ::Docker::Image.build(
                    docker_file,
                    {
                      'platform' => ENV['DOCKER_DEFAULT_PLATFORM'] || 'linux/amd64'
                    }
                  )
                end
      rescue StandardError => e
        Pero.log.debug docker_file
        Pero.log.error "failed build container #{e.inspect}"
        raise e
      end
      Pero.log.info 'success build container'
      image
    end

    def container_name
      "pero-#{Digest::MD5.hexdigest(Dir.pwd)[0..5]}-#{@environment}"
    end

    def find
      ::Docker::Container.all(all: true).find do |c|
        c.info['Names'].first == "/#{container_name}"
      end
    end

    def alerady_run?
      c = find
      c && c.info['State'] == 'running' && c
    end

    def run
      ::Docker::Container.all(all: true).each do |c|
        c.delete(force: true) if c.info['Names'].first == "/#{container_name}"
      end

      vols = volumes || []
      vols << "#{Dir.pwd}:/etc/puppetlabs/code/environments/#{@environment}"
      vols << "#{Dir.pwd}/keys:/etc/puppetlabs/puppet/eyaml/"

      container = ::Docker::Container.create({
                                               'name' => container_name,
                                               'Hostname' => 'puppet',
                                               'Image' => build.id,
                                               'ExposedPorts' => { '8140/tcp' => {} },
                                               'HostConfig' => {
                                                 'Binds' => vols,
                                                 'PortBindings' => {
                                                   '8140/tcp' => [{ 'HostPort' => '0' }]
                                                 }
                                               },
                                               'platform' => ENV['DOCKER_DEFAULT_PLATFORM'] || 'linux/amd64',
                                               'Cmd' => ['bash', '-c', "rm -rf #{conf_dir}/ssl/* && #{create_ca} && #{run_cmd}"]
                                             })

      Pero.log.info 'start puppet master container'
      container.start

      container = find
      raise "can't start container" unless container

      begin
        Retryable.retryable(tries: 20, sleep: 5) do
          https = Net::HTTP.new('localhost', container.info['Ports'].first['PublicPort'])
          https.use_ssl = true
          https.verify_mode = OpenSSL::SSL::VERIFY_NONE
          Pero.log.debug 'start server health check'
          https.start do
            response = https.get('/')
            Pero.log.debug "puppet http response #{response}"
          end
        rescue StandardError => e
          Pero.log.debug e.inspect
          raise e
        end
      rescue StandardError
        Pero.log.error "can't start container.please check [ docker logs #{container.info['id']} ]"
        container = find
        container.kill if container && container.info['State'] != 'exited'
        raise "can't start puppet server"
      end
      container
    end

    def puppet_config
      <<~EOS
        [master]
        vardir = /var/puppet
        certname = puppet
        dns_alt_names = puppet,localhost
        autosign = true
        environment_timeout = unlimited
        codedir = /etc/puppetlabs/code

        [main]
        server = puppet
        #{@environment && @environment != '' ? "environment = #{@environment}" : nil}
      EOS
    end

    def conf_dir
      if Gem::Version.new('4.0.0') > Gem::Version.new(server_version)
        '/etc/puppet'
      elsif Gem::Version.new('5.0.0') > Gem::Version.new(server_version) && Gem::Version.new('4.0.0') <= Gem::Version.new(server_version)
        '/etc/puppetlabs/puppet/'
      elsif Gem::Version.new('6.0.0') > Gem::Version.new(server_version) && Gem::Version.new('5.0.0') <= Gem::Version.new(server_version)
        '/etc/puppetlabs/puppet/'
      else
        '/etc/puppetlabs/puppet/'
      end
    end

    def docker_file
      release_package, package_name = if Gem::Version.new('4.0.0') > Gem::Version.new(server_version)
                                        ["puppetlabs-release-el-#{el}.noarch.rpm", 'puppet-server']
                                      elsif Gem::Version.new('5.0.0') > Gem::Version.new(server_version) && Gem::Version.new('4.0.0') <= Gem::Version.new(server_version)
                                        ["puppetlabs-release-pc1-el-#{el}.noarch.rpm", 'puppetserver']
                                      elsif Gem::Version.new('6.0.0') > Gem::Version.new(server_version) && Gem::Version.new('5.0.0') <= Gem::Version.new(server_version)
                                        ["puppet5-release-el-#{el}.noarch.rpm", 'puppetserver']
                                      elsif Gem::Version.new('7.0.0') > Gem::Version.new(server_version) && Gem::Version.new('6.0.0') <= Gem::Version.new(server_version)
                                        ["puppet6-release-el-#{el}.noarch.rpm", 'puppetserver']
                                      elsif Gem::Version.new('8.0.0') > Gem::Version.new(server_version) && Gem::Version.new('7.0.0') <= Gem::Version.new(server_version)
                                        ["puppet7-release-el-#{el}.noarch.rpm", 'puppetserver']
                                      else
                                        ["puppet8-release-el-#{el}.noarch.rpm", 'puppetserver']
                                      end

      vault_repo = if el == 6
                     <<~EOS
                       RUN sed -i "s|#baseurl=|baseurl=|g" /etc/yum.repos.d/CentOS-Base.repo \
                         && sed -i "s|mirrorlist=|#mirrorlist=|g" /etc/yum.repos.d/CentOS-Base.repo \
                         && sed -i "s|http://mirror\.centos\.org/|http://vault\.centos\.org/|g" /etc/yum.repos.d/CentOS-Base.repo
                     EOS
                   else
                     ''
                   end

      legacy_signing = if Gem::Version.new('3.0.0') > Gem::Version.new(server_version)
                         "RUN echo 'LegacySigningMDs md5' >> /etc/pki/tls/legacy-settings"
                       else
                         ''
                       end

      <<~EOS
        FROM #{from_image}
        #{vault_repo}
        #{legacy_signing}
        RUN curl -L -k -O https://yum.puppetlabs.com/#{release_package}  && \
        rpm -ivh #{release_package}
        RUN yum install -y #{package_name}-#{server_version}
        ENV PATH $PATH:/opt/puppetlabs/bin
        RUN echo -e "#{puppet_config.split(/\n/).join('\\n')}" > #{conf_dir}/puppet.conf
      EOS
    end

    def create_ca
      if Gem::Version.new('5.0.0') > Gem::Version.new(server_version)
        'puppet cert generate `hostname` --dns_alt_names localhost,127.0.0.1'
      elsif Gem::Version.new('6.0.0') > Gem::Version.new(server_version)
        'puppet cert generate `hostname` --dns_alt_names localhost,127.0.0.1'
      else
        'puppetserver ca setup --ca-name `hostname` --subject-alt-names DNS:localhost'
      end
    end

    def run_cmd
      if Gem::Version.new('3.0.0') > Gem::Version.new(server_version)
        # /var/puppet/run is created for the first time by running `puppet master`,
        # but `puppet master` will fail because the permissions are wrong.
        # So, let the `puppet master` fail once, fix the permission of /var/puppet/run, and execute `puppet master` again.
        'puppet master --no-daemonize --verbose || (chown puppet: /var/puppet/run && puppet master --no-daemonize --verbose)'
      elsif Gem::Version.new('5.0.0') > Gem::Version.new(server_version)
        'puppet master --no-daemonize --verbose'
      elsif Gem::Version.new('6.0.0') > Gem::Version.new(server_version)
        'puppetserver foreground'
      else
        'puppetserver foreground'
      end
    end

    def el
      if Gem::Version.new('3.5.1') > Gem::Version.new(server_version)
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
