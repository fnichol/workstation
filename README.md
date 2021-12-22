# Workstation Automation

|         |                                           |
| ------: | ----------------------------------------- |
|      CI | [![CI Status][badge-ci-overall]][ci]      |
| License | [![Crate license][badge-license]][github] |

**Table of Contents**

<!-- toc -->

- [Supported Platforms](#supported-platforms)
- [Installation](#installation)
  * [New System](#new-system)
  * [Existing System](#existing-system)
- [Usage](#usage)
- [Development and Testing](#development-and-testing)
  * [Alpine Linux](#alpine-linux)
  * [Arch Linux](#arch-linux)
  * [CentOS Linux](#centos-linux)
  * [FreeBSD](#freebsd)
  * [macOS](#macos)
  * [OpenBSD](#openbsd)
  * [Ubuntu Linux](#ubuntu-linux)
- [Code of Conduct](#code-of-conduct)
- [Issues](#issues)
- [Contributing](#contributing)
- [Authors](#authors)
- [License](#license)

<!-- tocstop -->

## Supported Platforms

Currently, the following platforms are supported (older and newer version may
also work):

- Alpine Linux (3.15)
- Arch Linux (rolling latest)
- CentOS (8)
- FreeBSD (13.0)
- macOS (10.15)
- OpenBSD (7.0)
- Ubuntu Linux (20.04)
- Windows 10 (2004)

## Installation

There are probably 2 use cases: running on a brand new system (before Git is
even installed), and on an existing system (presumably with Git installed).

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

To run the workstation prep with the `graphical` profile and set a hostname,
provide your FQDN as the argument:

```sh
./bin/prep <FQDN>
```

If an FQDN isn't provided, then your hostname is left as-is.

There are currently 3 profiles to select from `base`, `headless`, and
`graphical` with each profile building on the previous one. For example, running
the `headless` profile can be done with:

```sh
./bin/prep --profile=headless <FQDN>
```

A full usage is reported with the `--help` flag:

```console
> prep --help
prep 0.5.0

Workstation Setup

USAGE:
    prep [FLAGS] [OPTIONS] [--] [<FQDN>]

FLAGS:
    -h, --help      Prints help information
    -V, --version   Prints version information
    -v, --verbose   Prints verbose output

OPTIONS:
    -p, --profile=<PROFILE> Setup profile name
                            [values: base, headless, graphical]
                            [default: graphical]
    -o, --only=<T>[,<T>..]  Only run specific tasks
                            [values: hostname, pkg-init, update-system,
                            base-pkgs, preferences, keys, bashrc,
                            base-dot-configs, base-finalize, headless-pkgs,
                            rust, ruby, go, node, headless-finalize,
                            graphical-pkgs, graphical-dot-configs,
                            graphical-finalize]
    -s, --skip=<T>[,<T>..]  Skip specific tasks
                            [values: hostname, pkg-init, update-system,
                            base-pkgs, preferences, keys, bashrc,
                            base-dot-configs, base-finalize, headless-pkgs,
                            rust, ruby, go, node, headless-finalize,
                            graphical-pkgs, graphical-dot-configs,
                            graphical-finalize]

ARGS:
    <FQDN>  The name for this workstation
    <T>     Task name to include or skip

AUTHOR:
    Fletcher Nichol <fnichol@nichol.ca>

```

To update the codebase to the current state of the main branch you can run:

```sh
./bin/update
```

## Development and Testing

### Alpine Linux

Build the `headless` profile using Docker by running:

```sh
./support/bin/ci docker build alpine 3.12 headless
```

You can log into the instance with:

```sh
./support/bin/ci docker run -D '--rm -ti' alpine 3.12 headless
```

### Arch Linux

Build the `headless` profile using Docker by running:

```sh
./support/bin/ci docker build arch latest headless
```

You can log into the instance with:

```sh
./support/bin/ci docker run -D '--rm -ti' arch latest headless
```

### CentOS Linux

Build the `headless` profile using Docker by running:

```sh
./support/bin/ci docker build centos 8 headless
```

You can log into the instance with:

```sh
./support/bin/ci docker run -D '--rm -ti' centos 8 headless
```

### FreeBSD

Build the `headless` profile using Vagrant by running:

```sh
./support/bin/ci vagrant build freebsd 12.1 headless
```

You can log into the instance with:

```sh
./support/bin/ci vagrant console freebsd 12.1 headless
```

### macOS

The Vagrant box will need to be built via the
[Bento project](https://github.com/chef/bento) and added before this box will
work.

Build the `headless` profile using Vagrant by running:

```sh
./support/bin/ci vagrant build macos 10.12 headless
```

You can log into the instance with:

```sh
./support/bin/ci vagrant console macos 10.12 headless
```

### OpenBSD

Build the `headless` profile using Vagrant by running:

```sh
./support/bin/ci vagrant build openbsd 6.8 headless
```

You can log into the instance with:

```sh
./support/bin/ci vagrant console openbsd 6.8 headless
```

### Ubuntu Linux

Build the `headless` profile using Docker by running:

```sh
./support/bin/ci docker build ubuntu 20.04 headless
```

You can log into the instance with:

```sh
./support/bin/ci docker run -D '--rm -ti' ubuntu 20.04 headless
```

## Code of Conduct

This project adheres to the Contributor Covenant [code of
conduct][code-of-conduct]. By participating, you are expected to uphold this
code. Please report unacceptable behavior to fnichol@nichol.ca.

## Issues

If you have any problems with or questions about this project, please contact us
through a [GitHub issue][issues].

## Contributing

You are invited to contribute to new features, fixes, or updates, large or
small; we are always thrilled to receive pull requests, and do our best to
process them as fast as we can.

Before you start to code, we recommend discussing your plans through a [GitHub
issue][issues], especially for more ambitious contributions. This gives other
contributors a chance to point you in the right direction, give you feedback on
your design, and help you find out if someone else is working on the same thing.

## Authors

Created and maintained by [Fletcher Nichol][fnichol] (<fnichol@nichol.ca>).

## License

Licensed under the Mozilla Public License Version 2.0 ([LICENSE.txt][license]).

Unless you explicitly state otherwise, any contribution intentionally submitted
for inclusion in the work by you, as defined in the MPL-2.0 license, shall be
licensed as above, without any additional terms or conditions.

[badge-check-format]:
  https://img.shields.io/cirrus/github/fnichol/workstation.svg?style=flat-square&task=check&script=format
[badge-check-lint]:
  https://img.shields.io/cirrus/github/fnichol/workstation.svg?style=flat-square&task=check&script=lint
[badge-ci-overall]:
  https://img.shields.io/cirrus/github/fnichol/workstation.svg?style=flat-square
[badge-license]: https://img.shields.io/badge/License-MPL%202.0%20-blue.svg
[ci]: https://cirrus-ci.com/github/fnichol/workstation
[ci-master]: https://cirrus-ci.com/github/fnichol/workstation/master
[code-of-conduct]:
  https://github.com/fnichol/workstation/blob/master/CODE_OF_CONDUCT.md
[fnichol]: https://github.com/fnichol
[github]: https://github.com/fnichol/workstation
[issues]: https://github.com/fnichol/workstation/issues
[license]: https://github.com/fnichol/workstation/blob/master/LICENSE.txt
