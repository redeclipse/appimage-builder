Vagrant.configure("2") do |config|
  ENV["VAGRANT_DEFAULT_PROVIDER"] = "lxc"

  config.vm.box = "fgrehm/wheezy64-lxc"

  config.vm.provider :lxc do |lxc|
    # Same effect as 'customize ["modifyvm", :id, "--memory", "1024"]' for VirtualBox
    lxc.customize "cgroup.memory.limit_in_bytes", "1024M"
  end

end
