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
          CentOS.install(host, ssh, out.chomp, version)

          Pero.log.info "start puppet master container"
          container = run_container(version)
          begin
            forward_and_apply(host, user, options, port)
          ensure
            Pero.log.info "stop puppet master container"
            container.kill
          end
        end
      end

      def run_container(version)
        Pero::Docker.alerady_run? || Pero::Docker.run(Pero::Docker.build(version))
      end

      def forward_and_apply(host, user, options, port=8140)
        begin
          tmpdir=(0...8).map{ (65 + rand(26)).chr }.join
          Pero.log.info "start forwarding port:#{port}"
          ::Net::SSH.start(host, user) do |ssh|
            ssh.forward.remote(port, 'localhost', 8140)
            cmd = "sudo unshare -m -- /bin/bash -c 'install -o puppet -d /tmp/puppet/#{tmpdir} && \
                           mount --bind /tmp/puppet/#{tmpdir} /var/lib/puppet/ssl && \
                           puppet agent --no-daemonize --onetime #{options} --server localhost'"
            ssh.exec!(cmd)  do |channel, stream, data|
                             Pero.log.info "#{host}:#{data.chomp}" if stream == :stdout && data.chomp != ""
                           end
            ssh.exec!("sudo rm -rf /tmp/puppet/#{tmpdir}")
          end
        rescue => e
          Pero.log.error "puppet apply error:#{e.inspect}"
        ensure
        end
      end
    end
  end
end
