module Pero
  class Puppet
    class Ubuntu < Base
      def code_name
        case os_info[:release]
        when '20.04' then 'focal'
        when '22.04' then 'jammy'
        else raise "unsupported OS release: #{os_info[:release]}"
        end
      end

      def install(version)
        major_version = version.split('.')[0]
        release_package = "puppet#{major_version}-release"
        release_package_name = "#{release_package}-#{code_name}.deb"
        package_name = 'puppet-agent'
        package_version = "#{version}-1#{code_name}"

        unless run_specinfra(:check_package_is_installed, package_name, package_version)
          unless run_specinfra(:check_package_is_installed, release_package, '')
            Pero.log.info "install package #{release_package}"
            cmd = specinfra.run_command(<<~COMMAND)
              wget -O /tmp/#{release_package_name} https://apt.puppetlabs.com/#{release_package_name} &&
              dpkg -i /tmp/#{release_package_name} &&
              rm -f /tmp/#{release_package_name}
            COMMAND
            raise "failed package install:#{release_package} stdout:#{cmd.stdout}" if cmd.exit_status != 0
            specinfra.run_command('apt-get update -qqy')
          end

          Pero.log.info "install package #{package_name}-#{package_version}"
          raise "failed package install:#{package_name} version #{package_version}" if run_specinfra(:install_package, package_name, package_version).exit_status != 0
        else
          Pero.log.info "#{package_name}-#{package_version} installed"
        end
      end
    end
  end
end
