FROM centos:6
RUN yum -y install curl epel-release
RUN rpm -ivh https://yum.puppetlabs.com/el/6/products/x86_64/puppetlabs-release-6-12.noarch.rpm
RUN curl -O http://software.exogeni.net/repo/puppet/6/products/x86_64/puppet-server-3.0.1-1.el6.noarch.rpm && \
curl -O http://software.exogeni.net/repo/puppet/6/products/x86_64/puppet-3.0.1-1.el6.noarch.rpm && \
yum -y install puppet-3.0.1-1.el6.noarch.rpm puppet-server-3.0.1-1.el6.noarch.rpm
RUN mkdir -p /etc/puppetlabs/code/environments/production

RUN echo -e "[master]\nvardir= /var/puppet\nmanifestdir = $vardir//manifests\n templatedir = $vardir/templates\n modulepath  = $vardir/modules:$vardir/data/roles:$vardir/data/vendor/modules\nlogdir = /var/log/puppet\n rundir = /var/run/puppet\n ssldir = $vardir/ssl\n" > /etc/puppet/puppet.conf

CMD bash -c "rm -rf /etc/puppet/ssl/* && puppet cert generate `hostname` --dns_alt_names localhost,127.0.0.1 && echo '*' > /etc/puppet/autosign.conf && puppet master --no-daemonize --verbose"
