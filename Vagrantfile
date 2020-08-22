# -*- mode: ruby -*-
# vi: set ft=ruby :

# All Vagrant configuration is done below. The "2" in Vagrant.configure
# configures the configuration version (we support older styles for
# backwards compatibility). Please don't change it unless you know what
# you're doing.
Vagrant.require_version '>= 1.9.0'
plugins = [
  {
    plugin: 'vagrant-properties',
    version: '~> 0.9'
  },
  {
    plugin: 'vagrant-itamae',
    version: '~> 0.2'
  }
]

# 必須プラグインのチェック
plugins.each do |p|
  unless Vagrant.has_plugin?(p[:plugin], p[:version])
    action = Vagrant.has_plugin?(p[:plugin]) ? 'update' : 'install'
    Dir.chdir(Dir.home) { system "vagrant plugin #{action} #{p[:plugin]}" }
  end
end

Vagrant.configure("2") do |config|
  config.vm.box = "centos6"

  def define_machine_spec(config, memory=512, cpus=2)
    config.vm.provider :virtualbox do |vbox|
      vbox.customize ["modifyvm", :id, "--memory", memory.to_i]
      vbox.customize ["modifyvm", :id, "--cpus", cpus.to_i]
    end
  end

  config.vm.define 'client' do |c|
    c.vm.network :private_network, ip: "192.168.100.11"
    c.vm.hostname = "client.dev"
    define_machine_spec(c)
  end

  config.vm.define 'client7' do |c|
    config.vm.box = "centos/7"
    c.vm.network :private_network, ip: "192.168.100.12"
    c.vm.hostname = "client7.dev"
    define_machine_spec(c)
  end
end
