# -*- mode: ruby -*-
# vi: set ft=ruby :

# For information about how to build this box, see:
#
#     https://github.com/chef/bento#mac-os-x
#

Vagrant.configure("2") do |config|
  config.vm.box = "bento/macos-10.12"
  config.vm.synced_folder ".", "/src"

  config.vm.provider "vmware_fusion" do |v|
    v.gui = true

    v.vmx["memsize"] = (10 * 1024).to_s
    v.vmx["numvcpus"] = "3"
  end
end
