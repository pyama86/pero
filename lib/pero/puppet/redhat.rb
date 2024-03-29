module Pero
  class Puppet
    class Redhat < Base
      def self.show_versions_commands
        [
          %w(rpm -ivh https://yum.puppetlabs.com/puppetlabs-release-el-7.noarch.rpm),
          %w(yum --showduplicates search puppet),
          %w(yum remove -y puppetlabs-release),
          %w(rpm -ivh https://yum.puppetlabs.com/puppetlabs-release-pc1-el-7.noarch.rpm),
          %w(yum --showduplicates search puppet),
          %w(yum remove -y puppetlabs-release),
          %w(rpm -ivh https://yum.puppetlabs.com/puppet5-release-el-7.noarch.rpm),
          %w(yum --showduplicates search puppet),
          %w(yum remove -y puppet5-release),
          %w(rpm -ivh https://yum.puppetlabs.com/puppet6-release-el-7.noarch.rpm),
          %w(yum --showduplicates search puppet),
        ]
      end

      def self.show_versions
        image = ::Docker::Image.create('fromImage' => 'centos:7')
        init = image.run("/sbin/init")
        ret = []
        show_versions_commands.each do |c|
          init.exec(c, stdout:false, stderr: false) do |stream, chunk|
            chunk.split(/\n/).each do |r|
              ret << r.gsub(/\.el.*/, '')  if r =~ /(^puppet-3|^puppet-agent|^puppet-server|^puppetserver)/
            end
          end
        end
        puts ret.sort.join("\n")
        init.delete(:force => true)
      end


      def main_release
        os_info[:release].split(/\./)[0]
      end

      def install(version)
        release_package, package_name = if Gem::Version.new("4.0.0") > Gem::Version.new(version)
          ["puppetlabs-release-el-#{main_release}.noarch.rpm", "puppet"]
        elsif Gem::Version.new("5.0.0") > Gem::Version.new(version) && Gem::Version.new("4.0.0") <= Gem::Version.new(version)
          ["puppetlabs-release-pc1-el-#{main_release}.noarch.rpm", "puppet"]
        elsif Gem::Version.new("6.0.0") > Gem::Version.new(version) && Gem::Version.new("5.0.0") <= Gem::Version.new(version)
          ["puppet5-release-el-#{main_release}.noarch.rpm", "puppet-agent"]
        elsif Gem::Version.new("7.0.0") > Gem::Version.new(version) && Gem::Version.new("6.0.0") <= Gem::Version.new(version)
          ["puppet6-release-el-#{main_release}.noarch.rpm", "puppet-agent"]
        else
          ["puppet7-release-el-#{main_release}.noarch.rpm", "puppet-agent"]
        end

        unless run_specinfra(:check_package_is_installed, package_name, version)
          unless run_specinfra(:check_package_is_installed, release_package.gsub(/-el.*/, ''))
            Pero.log.info "install package #{release_package}"
            run_specinfra(:remove_package, "puppetlabs-release")
            run_specinfra(:remove_package, "puppet5-release")
            run_specinfra(:remove_package, "puppet6-release")
            raise "failed package install:#{release_package}" if specinfra.run_command("rpm -ivh https://yum.puppetlabs.com/#{release_package}").exit_status != 0
          end

          Pero.log.info "install package #{package_name}-#{version}"
          raise "failed package uninstall:#{package_name}" if run_specinfra(:remove_package, package_name).exit_status != 0
          raise "failed package install:#{package_name} version #{version}" if run_specinfra(:install_package, package_name, version).exit_status != 0
        else
          Pero.log.info "puppet-#{version} installed"
        end
      end
    end
  end
end
