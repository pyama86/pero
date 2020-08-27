FROM centos:6
RUN yum -y install curl epel-release
RUN rpm -ivh https://yum.puppetlabs.com/el/6/products/x86_64/puppetlabs-release-6-12.noarch.rpm
RUN curl -O http://software.exogeni.net/repo/puppet/6/products/x86_64/puppet-server-3.0.1-1.el6.noarch.rpm && \
curl -O http://software.exogeni.net/repo/puppet/6/products/x86_64/puppet-3.0.1-1.el6.noarch.rpm && \
yum -y install puppet-3.0.1-1.el6.noarch.rpm puppet-server-3.0.1-1.el6.noarch.rpm
CMD bash -c "rm -rf /etc/puppet/ssl/* && puppet cert generate `hostname` --dns_alt_names localhost,127.0.0.1 && puppet master --no-daemonize --verbose"
