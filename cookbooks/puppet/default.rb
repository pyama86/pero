execute '' do
  command <<-EOS
curl -L -k -O https://yum.puppetlabs.com/el/6/products/x86_64/puppetlabs-release-6-12.noarch.rpm
rpm -ivh puppetlabs-release-6-12.noarch.rpm
  EOS
  cwd '/tmp/'
  not_if 'rpm -qa |grep puppetlabs-release'
end

package 'puppet' do
  version node["puppet"]["version"]
end
