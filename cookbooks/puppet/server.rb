package 'puppet-server' do
  version node["puppet"]["version"]
end

execute 'create ca' do
  command <<-EOS
    puppet cert generate server.dev --dns_alt_names localhost,192.168.100.10
  EOS
  not_if 'test -e /var/lib/puppet/ssl/certs/server.dev.pem'
end

service 'puppetmaster' do
  action %i(start enable)
end

directory '/etc/puppet/manifests'
file '/etc/puppet/manifests/site.pp' do
  content <<-EOS
  notify {"puppet run ok":}
  EOS
  mode '0755'
end

