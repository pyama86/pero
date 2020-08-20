module Pero
  module Puppet
    class CentOS < Base
      class << self
        def install(host, ssh, elv, version)
          cmd = <<-EOS
          rpm -qa |grep puppetlabs > /dev/null || (cd /tmp && curl -L -k -O https://yum.puppetlabs.com/el/#{elv}/products/x86_64/puppetlabs-release-#{elv}-12.noarch.rpm && sudo rpm -ivh puppetlabs-release-#{elv}-12.noarch.rpm)
          EOS
          run_cmd(ssh, cmd, "#{host}:can't install puppetlabs-release")

          cmd = <<-EOS
          (rpm -qa | grep puppet- > /dev/null && rpm -qa | grep puppet-#{version} > /dev/null) || (sudo yum remove -y puppet)
          EOS
          run_cmd(ssh, cmd, "#{host}:can't uninstall puppet")

          cmd = <<-EOS
          rpm -qa |grep puppet-#{version} > /dev/null || (sudo yum install -y puppet-#{version})
          EOS
          run_cmd(ssh, cmd, "#{host}:can't install puppet version:#{version}")
        end
      end
    end
  end
end
