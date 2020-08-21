module Pero
  class Puppet
    class Redhat < Base
      def main_release
        os_info[:release].split(/\./)[0]
      end

      def install(version)
        installed = run_specinfra(:check_package_is_installed, "puppetlabs-release")
        unless installed
          run_specinfra(:install_package, "https://yum.puppetlabs.com/el/#{main_release}/products/x86_64/puppetlabs-release-#{main_release}-12.noarch.rpm")
        end

        unless run_specinfra(:check_package_is_installed, "puppet", version)
          run_specinfra(:remove_package, "puppet")
          run_specinfra(:install_package, "puppet", version)
        end
      end
    end
  end
end
