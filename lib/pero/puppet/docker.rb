require 'docker'
module Pero
  module Puppet
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
          container = ::Docker::Container.create({
            'Image' => image.id,
            'ExposedPorts' => { '8140/tcp' => {} },
            'HostConfig' => {
              'PortBindings' => {
                '8140/tcp' => [{ 'HostPort' => port.to_s }]
              }
            },
          })
          container.start('Binds' => ["#{Dir.pwd}:/etc/puppet"])
        end

        def docker_file(version)
          <<-EOS
          FROM #{from_image(version)}
          RUN curl -L -k -O https://yum.puppetlabs.com/el/#{el(version)}/products/x86_64/puppetlabs-release-#{el(version)}-12.noarch.rpm && \
          rpm -ivh puppetlabs-release-#{el(version)}-12.noarch.rpm && \
          yum --showduplicates search puppet && \
          yum install -y puppet-server-#{version} && \
          #{create_ca}
          CMD #{run_cmd}
          EOS
        end

        def create_ca
          'puppet cert generate server.pero --dns_alt_names localhost'
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
end
