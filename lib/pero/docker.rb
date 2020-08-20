require 'docker'
require 'digest/md5'
require "retryable"
require 'net/https'
module Pero
  class Docker
    class << self
      def build(version)
        Pero.log.info "start build container"
        begin
          image = ::Docker::Image.build(docker_file(version))
        rescue => e
          Pero.log.error "failed build container #{e.inspect}"
          raise e
        end
        Pero.log.info "success build container"
        image
      end

      def run(image, port=8140)
        Pero.log.info "start puppet master container"
        name = "pero-#{Digest::MD5.hexdigest(Dir.pwd)[0..5]}"

        all_container = ::Docker::Container.all(:all => true)
        all_container.each do |c|
          c.delete(:force => true) if c.info["Names"].first == "/#{name}"
        end

        container = ::Docker::Container.create({
          'name' => name,
          'Image' => image.id,
          'ExposedPorts' => { '8140/tcp' => {} },
        })

        container.start(
          'Binds' => ["#{Dir.pwd}:/var/puppet"],
          'PortBindings' => {
            '8140/tcp' => [{ 'HostPort' => port.to_s }],
          }
        )

        Retryable.retryable(tries: 10, sleep: 3) do
          https = Net::HTTP.new('localhost', port)
          https.use_ssl = true
          https.verify_mode = OpenSSL::SSL::VERIFY_NONE
          https.start {
            response = https.get('/')
          }
        end

        container
      end


      def docker_file(version)
        <<-EOS
          FROM #{from_image(version)}
          RUN curl -L -k -O https://yum.puppetlabs.com/el/#{el(version)}/products/x86_64/puppetlabs-release-#{el(version)}-12.noarch.rpm && \
          rpm -ivh puppetlabs-release-#{el(version)}-12.noarch.rpm && \
          yum install -y puppet-server-#{version}
          RUN echo "*" >> /etc/puppet/autosign.conf
          CMD bash -c "rm -rf /var/lib/puppet/ssl/* && #{create_ca} && #{run_cmd}"
        EOS
      end

      def create_ca
        '(puppet cert generate `hostname` --dns_alt_names localhost,127.0.0.1 || puppet cert --allow-dns-alt-names sign server.dev)'
      end

      def run_cmd
        'puppet master --no-daemonize --verbose'
      end

      def el(version)
        if Gem::Version.new("3.5.1") > Gem::Version.new(version)
          6
        else
          7
        end
      end

      def from_image(version)
        "centos:#{el(version)}"
      end
    end
  end
end
