# -*- mode: ruby -*-
# vi: set ft=ruby :
#
require 'pathname'

Vagrant.configure("2") do |config|
  basedir = Pathname.new("./support/distros/vagrant")
  boxes = Dir.children(basedir)
    .sort
    .map {|filename|
      IO.readlines(basedir.join(filename))
        .map {|line| "#{filename.sub(/\.txt$/, '')}-#{line.chomp}" }
    }
    .flatten
    .map {|kv| kv.split(",") }

  Hash[boxes].each do |name, box|
    %w{
      base
      headless
      graphical
    }.each do |profile|
      config.vm.define "workstation-#{name}-#{profile}", autostart: false do |c|
        c.vm.box = box

        if name.to_s.start_with?("freebsd")
          c.vm.synced_folder ".", "/vagrant", type: "rsync"
        end

        inline = "cd /vagrant && ./bin/prep --profile=#{profile}"
        if name.to_s.start_with?("freebsd")
          inline << " && sudo chsh -s /usr/local/bin/bash vagrant"
        end
        if name.to_s.start_with?("openbsd")
          inline << " && chsh -s /usr/local/bin/bash"
        end

        c.vm.provision "shell", privileged: false, inline: inline

        c.vm.provider "vmware_desktop" do |p|
          p.vmx["numvcpus"] = "3"
        end
        c.vm.provider "virtualbox" do |p|
          p.cpus = 3
        end
      end
    end
  end
end
