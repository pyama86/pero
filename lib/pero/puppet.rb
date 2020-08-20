require 'net/ssh'
module Pero
  module Puppet
    extend Pero::SshExecutable
    class << self
      def install_puppet(host, user, version, options, port=8140)
        Pero.log.info "bootstrap  puppet"
        ::Net::SSH.start(host, user) do |ssh|
          out, err, ret, _ = ssh_exec!(ssh, "rpm --eval %{centos_ver}")
          if ret == 1
            raise "sorry unsupport os, please pull request!!!"
          end
          CentOS.install(ssh, out.chomp, version)

          forward_and_apply(host, user, version, options, port)
        end
      end

      def run_container(version)
        image = Pero::Docker.build(version)
        Pero::Docker.run(image)
      end

      def forward_and_apply(host, user, version, options, port=8140)
        container = run_container(version)

        begin
          tmpdir=(0...8).map{ (65 + rand(26)).chr }.join
          Pero.log.info "begin forwarding port:#{port}"
          ::Net::SSH.start(host, user) do |ssh|
            ssh.forward.remote(port, 'localhost', 8140)

            puts ssh.exec!("sudo unshare -m -- /bin/bash -c 'install -o puppet -d /tmp/puppet/#{tmpdir} && \
                           mount --bind /tmp/puppet/#{tmpdir} /var/lib/puppet/ssl && \
                           puppet agent --no-daemonize --onetime --server localhost'")  do |channel, stream, data|
                             $stdout.write "host:#{data}" if stream == :stdout
                           end
            puts ssh.exec!("sudo rm -rf /tmp/puppet/#{tmpdir}")
          end
        ensure
          Pero.log.info "stop puppet master container"
          container.kill
        end
      end
    end
  end
end
