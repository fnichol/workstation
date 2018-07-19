# Workstation Preparation

Currently, the following platforms are supported (older and newer version may also work):

* Alpine Linux (3.6)
* Arch Linux (circa November 2017)
* CentOS (CentOS 7)
* FreeBSD (FreeBSD 11.1)
* macOS (10.12)
* Ubuntu Linux (17.10)
* Windows Subsystem for Linux on Windows 10 (Ubuntu)
* Windows 10 (1709)

## Installation

There are probably 2 use cases: running on a brand new system (before Git is even installed), and on an existing system (presumably with Git installed).

### New System

```sh
wget https://github.com/fnichol/workstation/archive/master.tar.gz
tar xfz master.tar.gz
cd workstation-master
```

Alternatively, if `wget` is not present you can use `curl`:

```sh
curl -LO https://github.com/fnichol/workstation/archive/master.tar.gz
```

### Existing System

```sh
git clone https://github.com/fnichol/workstation.git
cd workstation
```

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

### Alpine Linux

```sh
docker run -v $(pwd):/src -ti alpine:3.6 sh -c '\
  apk add --no-cache bash sudo \
  && echo "%wheel ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/01_wheel \
  && addgroup jdoe \
  && adduser -D -s /bin/bash -G jdoe jdoe \
  && adduser jdoe wheel \
  ; echo jdoe:1234 | chpasswd \
  ; su - jdoe'
```

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
docker run -v $(pwd):/src -ti ubuntu:17.10 bash -c '\
  apt-get update \
  && apt-get install -y sudo \
  && echo "%staff ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/01_staff \
  && useradd -m -s /bin/bash -G staff jdoe \
  ; echo jdoe:1234 | chpasswd \
  ; su - jdoe'
```
