# Workstation Preparation

Currently, the following platforms are supported (older and newer version may also work):

* Arch Linux (circa June 2017)
* CentOS (CentOS 7)
* macOS (10.12)
* Ubuntu Linux (17.04)

## Usage

To run the workstation prep and set a hostname, provide your FQDN as the argument:

```sh
bin/prep <FQDN>
```

If an FQDN isn't provided, then your hostname is left as-is.

To skip a full workstation setup and only run "base" setup, add the `-b` flag:

```sh
bin/prep -b <FQDN>
```

## Development and Testing

### Arch Linux

```sh
docker run -v $(pwd):/src -ti greyltc/archlinux bash -c '\
  pacman -Syy --noconfirm \
  && pacman -S --noconfirm sudo \
  && echo "%wheel ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/01_wheel \
  && useradd -m -s /bin/bash -G wheel jdoe \
  ; echo jdoe:1234 | chpasswd \
  ; su - jdoe'
```

### CentOS Linux

```sh
docker run -v $(pwd):/src -ti centos:7 bash -c '\
  yum install -y sudo \
  && echo "%adm ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/01_adm \
  && useradd -m -s /bin/bash -G adm jdoe \
  ; echo jdoe:1234 | chpasswd \
  ; su - jdoe'
```

### macOS

Vagrant with VMware Fusion is used to boot a macOS virtual machine.


### Ubuntu Linux

```sh
docker run -v $(pwd):/src -ti ubuntu:17.04 bash -c '\
  apt-get update \
  && apt-get install -y sudo \
  && echo "%staff ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/01_staff \
  && useradd -m -s /bin/bash -G staff jdoe \
  ; echo jdoe:1234 | chpasswd \
  ; su - jdoe'
```