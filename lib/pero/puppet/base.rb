module Pero
  module Puppet
    class Base
      extend Pero::SshExecutable
      class << self
        def run_cmd(ssh, cmd, errm="")
          out, err, ret, _ = ssh_exec!(ssh, cmd)
          if ret == 1
            Pero.log.error "#{errm}} error:#{err}"
            raise err
          end
          Pero.log.info out if out != ""
        end
      end
    end
  end
end
