package 'puppet-server' do
  version node["puppet"]["version"]
end

service 'puppetmaster' do
  action %i(start enable)
end

directory '/etc/puppet/manifests'
file '/etc/puppet/manifests/site.pp' do
  content <<-EOS
group { “example”:
  gid => 1000,
  ensure => present
}

#　ユーザーを作成する
user { “example”:
  ensure => present,
  home => “/home/example”,
  managehome => true,
  uid => 1000,
  gid => 1000,
  shell => “/bin/bash”,
  comment => “I'm Example”,
}
  EOS
end
