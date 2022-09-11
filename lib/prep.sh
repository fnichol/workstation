#!/usr/bin/env sh
# shellcheck disable=SC3043

print_usage() {
  local program="$1"
  local version="$2"
  local author="$3"

  echo "$program $version

    Workstation Setup

    USAGE:
        $program [FLAGS] [OPTIONS] [--] [<FQDN>]

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
                                base-dot-configs, base-finalize,
                                headless-pkgs, rust, ruby, go, node,
                                headless-finalize, graphical-pkgs,
                                graphical-dot-configs, graphical-finalize,
                                finish-base, finish-headless, finish-graphical]
        -s, --skip=<T>[,<T>..]  Skip specific tasks
                                [values: hostname, pkg-init, update-system,
                                base-pkgs, preferences, keys, bashrc,
                                base-dot-configs, base-finalize,
                                headless-pkgs, rust, ruby, go, node,
                                headless-finalize, graphical-pkgs,
                                graphical-dot-configs, graphical-finalize,
                                finish-base, finish-headless, finish-graphical]

    ARGS:
        <FQDN>  The name for this workstation
        <T>     Task name to include or skip

    AUTHOR:
        $author
    " | sed 's/^ \{1,4\}//g'
}

invoke_cli() {
  local program version author root
  program="$1"
  shift
  version="$1"
  shift
  author="$1"
  shift
  root="$1"
  shift

  VERBOSE=""
  onlys=""
  profile="graphical"
  skips=""

  OPTIND=1
  while getopts "ho:p:s:vV-:" arg; do
    case "$arg" in
      h)
        print_usage "$program" "$version" "$author"
        return 0
        ;;
      o)
        if are_onlys_valid "$program" "$version" "$author" "$OPTARG"; then
          onlys="$OPTARG"
        else
          return 1
        fi
        ;;
      p)
        if is_profile_valid "$OPTARG"; then
          profile="$OPTARG"
        else
          print_usage "$program" "$version" "$author" >&2
          die "invalid profile name $OPTARG"
        fi
        ;;
      s)
        if are_skips_valid "$program" "$version" "$author" "$OPTARG"; then
          skips="$OPTARG"
        else
          return 1
        fi
        ;;
      v)
        VERBOSE=true
        ;;
      V)
        print_version "$program" "$version" "${VERBOSE:-}"
        return 0
        ;;
      -)
        long_optarg="${OPTARG#*=}"
        case "$OPTARG" in
          help)
            print_usage "$program" "$version" "$author"
            return 0
            ;;
          only=?*)
            if are_onlys_valid "$program" "$version" "$author" "$long_optarg"; then
              onlys="$long_optarg"
            else
              return 1
            fi
            ;;
          only*)
            print_usage "$program" "$version" "$author" >&2
            die "missing required argument for --$OPTARG option"
            ;;
          profile=?*)
            if is_profile_valid "$long_optarg"; then
              profile="$long_optarg"
            else
              print_usage "$program" "$version" "$author" >&2
              die "invalid profile name '$long_optarg'"
            fi
            ;;
          profile*)
            print_usage "$program" "$version" "$author" >&2
            die "missing required argument for --$OPTARG option"
            ;;
          skip=?*)
            if are_skips_valid "$program" "$version" "$author" "$long_optarg"; then
              skips="$long_optarg"
            else
              return 1
            fi
            ;;
          skip*)
            print_usage "$program" "$version" "$author" >&2
            die "missing required argument for --$OPTARG option"
            ;;
          verbose)
            VERBOSE=true
            ;;
          version)
            print_version "$program" "$version" "${VERBOSE:-}"
            return 0
            ;;
          '')
            # "--" terminates argument processing
            break
            ;;
          *)
            print_usage "$program" "$version" "$author" >&2
            die "invalid argument --$OPTARG"
            ;;
        esac
        ;;
      \?)
        print_usage "$program" "$version" "$author" >&2
        die "invalid argument; arg=-$OPTARG"
        ;;
    esac
  done
  shift "$((OPTIND - 1))"

  if [ -n "${1:-}" ]; then
    _argv_hostname="$1"
  fi

  if [ "$(uname -s)" = "Darwin" ] \
    && [ "$profile" = "graphical" ] \
    && [ ! -f "$HOME/Library/Preferences/com.apple.appstore.plist" ]; then
    printf -- "Not logged into App Store, please login and try again.\n\n"
    print_usage "$program" "$version" "$author" >&2
    die "must be logged into App Store"
  fi

  prepare_workstation "$program" "$root" "$profile" "$skips" "$onlys"
}

prepare_workstation() {
  local program="$1"
  local root="$2"
  local profile="$3"
  local skips="$4"
  local onlys="$5"

  if [ -n "$VERBOSE" ]; then
    echo "root: $root"
    echo "profile: $profile"
    echo "skip: $skips"
    echo "only: $onlys"
  fi

  setup_cleanups
  setup_traps trap_cleanups

  init "$program" "$root"
  if should_run_task "hostname" "$skips" "$onlys"; then
    set_hostname
  fi
  if should_run_task "pkg-init" "$skips" "$onlys"; then
    setup_package_system
  fi
  if should_run_task "update-system" "$skips" "$onlys"; then
    update_system
  fi
  if should_run_task "base-pkgs" "$skips" "$onlys"; then
    install_base_packages
  fi
  if should_run_task "preferences" "$skips" "$onlys"; then
    set_preferences
  fi
  if should_run_task "keys" "$skips" "$onlys"; then
    generate_keys
  fi
  if should_run_task "bashrc" "$skips" "$onlys"; then
    install_bashrc
  fi
  if should_run_task "base-dot-configs" "$skips" "$onlys"; then
    install_base_dot_configs
  fi
  if should_run_task "base-finalize" "$skips" "$onlys"; then
    finalize_base_setup
  fi

  if [ "$profile" = "headless" ] || [ "$profile" = "graphical" ]; then
    if should_run_task "headless-pkgs" "$skips" "$onlys"; then
      install_headless_packages
    fi
    if should_run_task "rust" "$skips" "$onlys"; then
      install_rust
    fi
    if should_run_task "ruby" "$skips" "$onlys"; then
      install_ruby
    fi
    if should_run_task "go" "$skips" "$onlys"; then
      install_go
    fi
    if should_run_task "node" "$skips" "$onlys"; then
      install_node
    fi
    if should_run_task "headless-finalize" "$skips" "$onlys"; then
      finalize_headless_setup
    fi
  fi

  if [ "$profile" = "graphical" ]; then
    if should_run_task "graphical-pkgs" "$skips" "$onlys"; then
      install_graphical_packages
    fi
    if should_run_task "graphical-dot-configs" "$skips" "$onlys"; then
      install_graphical_dot_configs
    fi
    if should_run_task "graphical-finalize" "$skips" "$onlys"; then
      finalize_graphical_setup
    fi
  fi

  if should_run_task "finish-base" "$skips" "$onlys"; then
    finish_base_setup
  fi
  if [ "$profile" = "headless" ] || [ "$profile" = "graphical" ]; then
    if should_run_task "finish-headless" "$skips" "$onlys"; then
      finish_headless_setup
    fi
  fi
  if [ "$profile" = "graphical" ]; then
    if should_run_task "finish-graphical" "$skips" "$onlys"; then
      finish_graphical_setup
    fi
  fi

  finish
}

are_onlys_valid() {
  need_cmd tr

  local program="$1"
  local version="$2"
  local author="$3"
  local onlys="$4"

  for only in $(echo "$onlys" | tr ',' ' '); do
    if ! is_task_valid "$only"; then
      print_usage "$program" "$version" "$author" >&2
      die "invalid only task: $only"
    fi
  done
}

are_skips_valid() {
  need_cmd tr

  local program="$1"
  local version="$2"
  local author="$3"
  local skips="$4"

  for skip in $(echo "$skips" | tr ',' ' '); do
    if ! is_task_valid "$skip"; then
      print_usage "$program" "$version" "$author" >&2
      die "invalid skip task: $skip"
    fi
  done
}

is_profile_valid() {
  local profile="$1"

  case "$profile" in
    base | headless | graphical)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

is_task_valid() {
  local task="$1"

  case "$task" in
    hostname | pkg-init | update-system | base-pkgs | preferences | keys | \
      bashrc | base-dot-configs | base-finalize | headless-pkgs | rust | \
      ruby | go | node | headless-finalize | graphical-pkgs | \
      graphical-dot-configs | graphical-finalize | finish-base | \
      finish-headless | finish-graphical)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

should_run_task() {
  local task="$1"
  local skips="$2"
  local onlys="$3"

  if [ -n "$onlys" ]; then
    if is_task_in "$task" "$onlys" && ! is_task_in "$task" "$skips"; then
      return 0
    else
      return 1
    fi
  else
    if ! is_task_in "$task" "$skips"; then
      return 0
    else
      return 1
    fi
  fi
}

is_task_in() {
  need_cmd grep
  need_cmd tr

  local task="$1"
  local tasks="$2"

  if echo "$tasks" | tr ',' '\n' | grep -q -E "^$task$"; then
    return 0
  else
    return 1
  fi
}

init() {
  need_cmd basename
  need_cmd uname

  local program="$1"
  local root="$2"
  local lib_path="$root/lib"
  local hostname

  _system="$(uname -s)"

  _data_path="$root/data"
  _asset_path="$root/assets"

  if [ "$_system" != "Linux" ]; then
    _os="$_system"
  elif [ -f /etc/lsb-release ]; then
    _os="$(
      # shellcheck source=/dev/null
      . /etc/lsb-release
      echo "$DISTRIB_ID"
    )"
  elif [ -f /etc/alpine-release ]; then
    _os="Alpine"
  elif [ -f /etc/arch-release ]; then
    _os="Arch"
  elif [ -f /etc/redhat-release ]; then
    _os="RedHat"
  else
    _os="Unknown"
  fi

  case "$_system" in
    Darwin)
      # shellcheck source=lib/unix.sh
      . "$lib_path/unix.sh"
      # shellcheck source=lib/darwin.sh
      . "$lib_path/darwin.sh"
      ;;
    FreeBSD)
      # shellcheck source=lib/unix.sh
      . "$lib_path/unix.sh"
      # shellcheck source=lib/freebsd.sh
      . "$lib_path/freebsd.sh"
      ;;
    Linux)
      # shellcheck source=lib/unix.sh
      . "$lib_path/unix.sh"
      # shellcheck source=lib/linux.sh
      . "$lib_path/linux.sh"

      case "$_os" in
        Arch)
          # shellcheck source=lib/arch.sh
          . "$lib_path/arch.sh"
          ;;
      esac
      ;;
    OpenBSD)
      # shellcheck source=lib/unix.sh
      . "$lib_path/unix.sh"
      # shellcheck source=lib/openbsd.sh
      . "$lib_path/openbsd.sh"
      ;;
  esac

  case "$_os" in
    Arch)
      need_cmd hostnamectl

      hostname="$(hostnamectl --transient)"
      ;;
    *)
      need_cmd hostname

      hostname="$(hostname)"
      ;;
  esac

  section "Setting up workstation '${_argv_hostname:-$hostname}'"

  if [ "${PREP_RUN_AS_ROOT:-}" != "true" ]; then
    ensure_not_root "$program"
    get_sudo "$hostname"
    keep_sudo
  fi

  if [ "$_system" = "Darwin" ]; then
    darwin_check_tmux
    # Close any open System Preferences panes, to prevent them from overriding
    # settings we’re about to change
    osascript -e 'tell application "System Preferences" to quit'
  fi
  sanitize_path
}

sanitize_path() {
  section "Sanitizing PATH entries that could affect package installation/setup"
  # If a volta installation is detected, remove it from PATH so that
  # built-from-source packages such as cider on Arch Linux won't use
  # volta-provided Node/NPM packages and rather prefer system-provided versions
  # (as those packages would expect)
  local volta_bin_path="$HOME/.volta/bin"
  if echo "$PATH" | tr ':' '\n' | grep -q "^${volta_bin_path}$"; then
    info "Removing volta bin path '$volta_bin_path' from PATH"
    PATH="$(echo "$PATH" | sed -e "s,${volta_bin_path}:\?,,")"
  fi
}

set_hostname() {
  if [ -z "${_argv_hostname:-}" ]; then
    return 0
  fi

  local fqdn
  local name="${_argv_hostname%%.*}"
  if [ "$_argv_hostname" = "$name" ]; then
    fqdn="${name}.local"
  else
    fqdn="$_argv_hostname"
  fi

  section "Setting hostname to '$fqdn'"
  case "$_os" in
    Arch)
      arch_set_hostname "$name" "$fqdn"
      ;;
    Darwin)
      darwin_set_hostname "$name" "$fqdn"
      ;;
    FreeBSD)
      freebsd_set_hostname "$fqdn"
      ;;
    OpenBSD)
      openbsd_set_hostname "$fqdn"
      ;;
    Ubuntu)
      need_cmd grep
      need_cmd hostname
      need_cmd sed
      need_cmd sudo
      need_cmd tee

      local old_hostname
      old_hostname="$(hostname -f)"

      if [ "$old_hostname" != "$name" ]; then
        echo "$name" | sudo tee /etc/hostname >/dev/null
        sudo hostname -F /etc/hostname
        if ! grep -q -w "$fqdn" /etc/hosts; then
          sudo sed -i "1i 127.0.0.1\\t${fqdn}\\t${name}" /etc/hosts
        fi
        if command -v hostnamectl; then
          sudo hostnamectl set-hostname "$name"
        fi
        if [ -f /etc/init.d/hostname ]; then
          sudo /etc/init.d/hostname start || true
        fi
        if [ -f /etc/init.d/hostname.sh ]; then
          sudo /etc/init.d/hostname.sh start || true
        fi
      fi
      ;;
    *)
      warn "Setting hostname on $_os not yet supported, skipping"
      ;;
  esac
}

setup_package_system() {
  section "Setting up package system"

  case "$_os" in
    Alpine)
      indent sudo apk update
      ;;
    Arch)
      arch_setup_package_system
      ;;
    Darwin)
      darwin_setup_package_system
      ;;
    FreeBSD)
      freebsd_setup_package_system
      ;;
    OpenBSD)
      # Nothing to do
      ;;
    RedHat)
      # Nothing to do
      ;;
    Ubuntu)
      indent sudo apt-get update
      ;;
    *)
      warn "Setting up package system on $_os not yet supported, skipping"
      ;;
  esac
}

update_system() {
  section "Applying system updates"

  case "$_os" in
    Alpine)
      indent sudo apk upgrade
      ;;
    Arch)
      arch_update_system
      ;;
    Darwin)
      darwin_update_system
      ;;
    FreeBSD)
      freebsd_update_system
      ;;
    OpenBSD)
      openbsd_update_system
      ;;
    RedHat)
      # Nothing to do
      ;;
    Ubuntu)
      indent sudo apt-get -y dist-upgrade
      ;;
    *)
      warn "Setting up package system on $_os not yet supported, skipping"
      ;;
  esac
}

install_base_packages() {
  section "Installing base packages"

  case "$_os" in
    Alpine)
      install_pkg jq
      install_pkgs_from_json "$_data_path/alpine_base_pkgs.json"
      ;;
    Arch)
      arch_install_base_packages "$_data_path"
      ;;
    Darwin)
      darwin_install_base_packages "$_data_path"
      ;;
    FreeBSD)
      freebsd_install_base_packages "$_data_path"
      ;;
    OpenBSD)
      openbsd_install_base_packages "$_data_path"
      ;;
    RedHat)
      redhat_install_jq
      install_pkgs_from_json "$_data_path/redhat_base_pkgs.json"
      ;;
    Ubuntu)
      install_pkg jq
      install_pkgs_from_json "$_data_path/ubuntu_base_pkgs.json"
      ;;
    *)
      warn "Installing packages on $_os not yet supported, skipping"
      ;;
  esac
}

set_preferences() {
  section "Setting preferences"

  case "$_os" in
    Alpine)
      # Nothing to do
      ;;
    Arch)
      # Nothing to do
      ;;
    Darwin)
      darwin_set_preferences "$_asset_path"
      ;;
    FreeBSD)
      # Nothing to do
      ;;
    OpenBSD)
      # Nothing to do
      ;;
    RedHat)
      # Nothing to do
      ;;
    Ubuntu)
      # Nothing to do
      ;;
    *)
      warn "Installing packages on $_os not yet supported, skipping"
      ;;
  esac
}

generate_keys() {
  section "Generating keys"

  need_cmd chmod
  need_cmd date
  need_cmd mkdir
  need_cmd ssh-keygen

  local hostname
  case "$_os" in
    OpenBSD)
      need_cmd cat
      hostname="$(cat /etc/myname)"
      ;;
    *)
      need_cmd hostname
      hostname="$(hostname -f)"
      ;;
  esac

  if [ ! -f "$HOME/.ssh/id_rsa" ]; then
    info "Generating SSH key for '$USER' on this system"
    mkdir -p "$HOME/.ssh"
    indent ssh-keygen \
      -N '' \
      -C "${USER}@${hostname}-$(date -u +%FT%TZ)" \
      -t rsa \
      -b 4096 \
      -a 100 \
      -f "$HOME/.ssh/id_rsa"
    chmod 0700 "$HOME/.ssh"
    chmod 0600 "$HOME/.ssh/id_rsa"
    chmod 0644 "$HOME/.ssh/id_rsa.pub"
  fi
}

install_bashrc() {
  need_cmd bash

  local sudo
  case "$_os" in
    OpenBSD)
      need_cmd doas
      sudo="doas"
      ;;
    *)
      need_cmd sudo
      sudo="sudo"
      ;;
  esac

  if [ -f /etc/bash/bashrc.local ]; then
    section "Updating fnichol/bashrc"
    indent bash -c "source /etc/bash/bashrc && bashrc update"
  else
    local install_sh
    install_sh="$(mktemp_file)"
    cleanup_file "$install_sh"

    section "Installing fnichol/bashrc"
    download \
      https://raw.githubusercontent.com/fnichol/bashrc/master/contrib/install-system-wide \
      "$install_sh"
    info "Running installer"
    indent "$sudo" bash "$install_sh"
  fi

}

install_base_dot_configs() {
  need_cmd cut
  need_cmd git

  local repo repo_dir castle

  section "Installing base dot configs"

  if [ ! -f "$HOME/.homesick/repos/homeshick/homeshick.sh" ]; then
    info "Installing homeshick for '$USER'"
    indent git clone --depth 1 https://github.com/andsens/homeshick.git \
      "$HOME/.homesick/repos/homeshick"
  fi

  json_items "$_data_path/homesick_base_repos.json" | while read -r repo; do
    manage_homesick_repo "$repo"
  done
}

finalize_base_setup() {
  section "Finalizing base setup"

  case "$_os" in
    Alpine)
      # Nothing to do yet
      ;;
    Arch)
      # Nothing to do yet
      ;;
    Darwin)
      darwin_finalize_base_setup
      ;;
    FreeBSD)
      # Nothing to do yet
      ;;
    OpenBSD)
      openbsd_finalize_base_setup
      ;;
    RedHat)
      # Nothing to do yet
      ;;
    Ubuntu)
      # Nothing to do yet
      ;;
    *)
      warn "Finalizing base setup on $_os not yet supported, skipping"
      ;;
  esac
}

install_headless_packages() {
  section "Installing headless packages"

  case "$_os" in
    Alpine)
      install_pkgs_from_json "$_data_path/alpine_headless_pkgs.json"
      ;;
    Arch)
      arch_install_headless_packages "$_data_path"
      ;;
    Darwin)
      darwin_install_headless_packages "$_data_path"
      ;;
    FreeBSD)
      freebsd_install_headless_packages "$_data_path"
      ;;
    OpenBSD)
      openbsd_install_headless_packages "$_data_path"
      ;;
    RedHat)
      install_pkgs_from_json "$_data_path/redhat_headless_pkgs.json"
      ;;
    Ubuntu)
      install_pkgs_from_json "$_data_path/ubuntu_headless_pkgs.json"
      ;;
    *)
      warn "Installing headless packages on $_os not yet supported, skipping"
      ;;
  esac
}

install_rust() {
  local cargo_home="$HOME/.cargo"
  local cargo="$cargo_home/bin/cargo"
  local rustup="$cargo_home/bin/rustup"
  local installed_plugins

  section "Setting up Rust"

  if [ "$_os" = Alpine ]; then
    warn "Alpine Linux not supported, skipping Rust installation"
    return 0
  fi

  case "$_os" in
    OpenBSD)
      cargo=/usr/local/bin/cargo

      openbsd_install_rust
      ;;
    *)
      if [ ! -x "$rustup" ]; then
        local install_sh
        install_sh="$(mktemp_file)"
        cleanup_file "$install_sh"

        info "Installing Rust"
        download https://sh.rustup.rs "$install_sh"
        indent sh "$install_sh" -y --default-toolchain stable
      fi

      indent "$rustup" self update
      indent "$rustup" update

      indent "$rustup" component add rust-src
      indent "$rustup" component add rustfmt
      ;;
  esac

  installed_plugins="$("$cargo" install --list | grep ':$' | cut -d ' ' -f 1)"
  json_items "$_data_path/rust_cargo_plugins.json" | while read -r plugin; do
    if ! echo "$installed_plugins" | grep -q "^$plugin\$"; then
      info "Installing $plugin"
      indent "$cargo" install --locked "$plugin"
    fi
  done

  info "Updating Cargo plugins"
  indent "$cargo" install-update --all
}

install_ruby() {
  section "Setting up Ruby"

  if [ "$_os" = Alpine ]; then
    warn "Alpine Linux not supported, skipping Ruby installation"
    return 0
  fi

  case "$_system" in
    Darwin)
      install_pkg chruby
      install_pkg ruby-install
      ;;
    FreeBSD | Linux | OpenBSD)
      unix_install_chruby
      unix_install_ruby_install
      ;;
    *)
      warn "Installing Ruby on $_os not yet supported, skipping"
      return 0
      ;;
  esac

  need_cmd uname

  local sudo
  case "$(uname -s)" in
    OpenBSD)
      need_cmd doas
      sudo="doas"
      ;;
    *)
      need_cmd sudo
      sudo="sudo"
      ;;
  esac

  # If this is the initial install or if the cache is older than 12 hours,
  # update the list of Ruby versions
  local checked_versions="$HOME/.cache/ruby-install/ruby/versions.txt"
  if [ ! -f "$checked_versions" ] \
    || [ -n "$(find "$checked_versions" -mmin +720)" ]; then
    info "Updating the list of Ruby versions"
    indent ruby-install --latest
  fi

  # Install latest stable version of Ruby
  indent ruby-install --no-reinstall ruby

  "$sudo" mkdir -p /etc/profile.d

  if [ ! -f /etc/profile.d/chruby.sh ]; then
    info "Creating /etc/profile.d/chruby.sh"
    cat <<-EOF | "$sudo" tee /etc/profile.d/chruby.sh >/dev/null
	source /usr/local/share/chruby/chruby.sh
	source /usr/local/share/chruby/auto.sh
	EOF
  fi

  if [ ! -f /etc/profile.d/renv.sh ]; then
    local renv_sh
    renv_sh="$(mktemp_file)"
    cleanup_file "$renv_sh"

    info "Creating /etc/profile.d/renv.sh"
    download \
      https://raw.githubusercontent.com/fnichol/renv/master/renv.sh \
      "$renv_sh"
    "$sudo" cp "$renv_sh" /etc/profile.d/renv.sh
    "$sudo" chmod 0644 /etc/profile.d/renv.sh
  fi

  if [ ! -f "$HOME/.ruby-version" ]; then
    info "Creating ~/.ruby-version"
    echo "ruby" >"$HOME/.ruby-version"
  fi
}

install_go() {
  section "Setting up Go"

  case "$_os" in
    Alpine | OpenBSD)
      install_pkg go
      return 0
      ;;
    *)
      # Nothing to do
      ;;
  esac

  need_cmd cat
  need_cmd rm
  need_cmd sudo

  # https://golang.org/dl/
  local ver
  ver="$(latest_go_version)"

  if [ -f /usr/local/go/VERSION ]; then
    local installed_ver
    installed_ver="$(cat /usr/local/go/VERSION)"
    if [ "$installed_ver" = "$ver" ]; then
      info "Current version '$ver' is installed"
      return 0
    else
      info "Uninstalling Go $installed_ver"
      sudo rm -rf /usr/local/go
    fi
  fi

  need_cmd uname
  need_cmd mkdir
  need_cmd tar

  local arch kernel machine tar
  kernel="$(uname -s | tr '[:upper:]' '[:lower:]')"
  machine="$(uname -m)"
  tar="$(mktemp_file)"
  cleanup_file "$tar"

  case "$machine" in
    x86_64 | amd64)
      arch="amd64"
      ;;
    i686)
      arch="386"
      ;;
    *)
      die "Installation of Go not currently supported for $machine"
      ;;
  esac

  info "Installing Go $ver"
  sudo mkdir -p /usr/local
  download \
    "https://storage.googleapis.com/golang/${ver}.${kernel}-${arch}.tar.gz" \
    "$tar"
  sudo tar xf "$tar" -C /usr/local
}

install_node() {
  local volta_home="$HOME/.volta"
  local volta="$volta_home/bin/volta"

  section "Setting up Node"

  case "$_os" in
    Alpine)
      warn "Alpine Linux not supported, skipping Node installation"
      return 0
      ;;
    FreeBSD)
      freebsd_install_node
      return 0
      ;;
    OpenBSD)
      openbsd_install_node
      return 0
      ;;
  esac

  unix_install_volta "$volta"

  indent "$volta" install node@latest
}

finalize_headless_setup() {
  section "Finalizing headless setup"

  case "$_os" in
    Alpine)
      # Nothing to do yet
      ;;
    Arch)
      arch_finalize_headless_setup
      ;;
    Darwin)
      darwin_finalize_headless_setup
      ;;
    FreeBSD)
      # Nothing to do yet
      ;;
    OpenBSD)
      # Nothing to do yet
      ;;
    RedHat)
      # Nothing to do yet
      ;;
    Ubuntu)
      # Nothing to do yet
      ;;
    *)
      warn "Finalizing headless setup on $_os not yet supported, skipping"
      ;;
  esac
}

install_graphical_packages() {
  section "Installing graphical packages"

  case "$_os" in
    Alpine)
      # Nothing to do yet
      ;;
    Arch)
      arch_install_graphical_packages "$_data_path"
      ;;
    Darwin)
      darwin_install_graphical_packages "$_data_path"
      ;;
    FreeBSD)
      # Nothing to do yet
      ;;
    OpenBSD)
      openbsd_install_graphical_packages "$_data_path"
      ;;
    RedHat)
      # Nothing to do yet
      ;;
    Ubuntu)
      # Nothing to do yet
      ;;
    *)
      warn "Installing graphical packages on $_os not yet supported, skipping"
      ;;
  esac
}

install_graphical_dot_configs() {
  local repo

  section "Installing graphical dot configs"

  case "$_os" in
    Alpine)
      # Nothing to do yet
      ;;
    Arch)
      manage_homesick_repo "fnichol/dotx"
      ;;
    Darwin)
      manage_homesick_repo "fnichol/dotmac"
      ;;
    FreeBSD)
      # Nothing to do yet
      ;;
    OpenBSD)
      manage_homesick_repo "fnichol/dotx"
      ;;
    RedHat)
      # Nothing to do yet
      ;;
    Ubuntu)
      # Nothing to do yet
      ;;
    *)
      warn "Finalizing graphical setup on $_os not yet supported, skipping"
      ;;
  esac
}

finalize_graphical_setup() {
  section "Finalizing graphical setup"

  case "$_os" in
    Alpine)
      # Nothing to do yet
      ;;
    Arch)
      arch_finalize_graphical_setup
      ;;
    Darwin)
      darwin_finalize_graphical_setup
      ;;
    FreeBSD)
      # Nothing to do yet
      ;;
    OpenBSD)
      # Nothing to do yet
      ;;
    RedHat)
      # Nothing to do yet
      ;;
    Ubuntu)
      # Nothing to do yet
      ;;
    *)
      warn "Finalizing graphical setup on $_os not yet supported, skipping"
      ;;
  esac
}

finish_base_setup() {
  section "Finishing base setup"

  case "$_os" in
    Alpine)
      # Nothing to do yet
      ;;
    Arch)
      # Nothing to do yet
      ;;
    Darwin)
      # Nothing to do yet
      ;;
    FreeBSD)
      # Nothing to do yet
      ;;
    OpenBSD)
      # Nothing to do yet
      ;;
    RedHat)
      # Nothing to do yet
      ;;
    Ubuntu)
      # Nothing to do yet
      ;;
    *)
      warn "Finishing base setup on $_os not yet supported, skipping"
      ;;
  esac
}

finish_headless_setup() {
  section "Finishing headless setup"

  case "$_os" in
    Alpine)
      # Nothing to do yet
      ;;
    Arch)
      # Nothing to do yet
      ;;
    Darwin)
      # Nothing to do yet
      ;;
    FreeBSD)
      # Nothing to do yet
      ;;
    OpenBSD)
      # Nothing to do yet
      ;;
    RedHat)
      # Nothing to do yet
      ;;
    Ubuntu)
      # Nothing to do yet
      ;;
    *)
      warn "Finishing headless setup on $_os not yet supported, skipping"
      ;;
  esac
}

finish_graphical_setup() {
  section "Finishing graphical setup"

  case "$_os" in
    Alpine)
      # Nothing to do yet
      ;;
    Arch)
      # Nothing to do yet
      ;;
    Darwin)
      # Nothing to do yet
      ;;
    FreeBSD)
      # Nothing to do yet
      ;;
    OpenBSD)
      # Nothing to do yet
      ;;
    RedHat)
      # Nothing to do yet
      ;;
    Ubuntu)
      # Nothing to do yet
      ;;
    *)
      warn "Finishing graphical setup on $_os not yet supported, skipping"
      ;;
  esac
}

finish() {
  section "Finished setting up workstation, enjoy!"
}

install_pkg() {
  case "$_os" in
    Alpine)
      alpine_install_pkg "$1"
      ;;
    Arch)
      arch_install_pkg "$1"
      ;;
    Darwin)
      darwin_install_pkg "$@"
      ;;
    FreeBSD)
      freebsd_install_pkg "$1"
      ;;
    OpenBSD)
      openbsd_install_pkg "$1"
      ;;
    RedHat)
      redhat_install_pkg "$1"
      ;;
    Ubuntu)
      ubuntu_install_pkg "$1"
      ;;
    *)
      warn "Installing package on $_os not yet supported, skipping..."
      ;;
  esac
}

install_pip3_pkg() {
  need_cmd jq

  local pkg="$1"
  local pip_cmd use_sudo

  case "$_os" in
    Darwin)
      pip_cmd=pip3
      use_sudo=false
      ;;
    FreeBSD)
      need_cmd uname

      local release
      release="$(uname -r)"

      case "$release" in
        12.*)
          pip_cmd=pip-3.7
          ;;
        11.*)
          pip_cmd=pip-3.6
          ;;
        *)
          warn "Installing a pip pkg on $release not yet supported, skipping..."
          return 1
          ;;
      esac

      use_sudo=true
      ;;
    *)
      warn "Installing a pip pkg on $_os not yet supported, skipping..."
      return 1
      ;;
  esac

  need_cmd "$pip_cmd"

  if env PIP_FORMAT=json "$pip_cmd" list \
    | jq -r '.[] | .name' | grep -q "^${pkg}$" >/dev/null 2>&1; then
    return 0
  fi

  info "Installing pip3 package '$pkg'"
  if [ "$use_sudo" = true ]; then
    indent sudo "$pip_cmd" install "$pkg"
  else
    indent "$pip_cmd" install "$pkg"
  fi
}

install_pkgs_from_json() {
  local json="$1"
  local cache
  cache="$(mktemp_file)"
  cleanup_file "$cache"
  # Ensure no file exists
  rm -f "$cache"

  json_items "$json" | while read -r pkg; do
    install_pkg "$pkg" "$cache"
  done
}

manage_homesick_repo() {
  local repo="$1"
  local repo_dir castle cmd

  need_cmd bash
  need_cmd cut

  castle="$(echo "$repo" | cut -d '/' -f 2)"
  repo_dir="$HOME/.homesick/repos/$castle"
  cmd="$HOME/.homesick/repos/homeshick/bin/homeshick"

  if [ ! -d "$repo_dir" ]; then
    info "Installing repo $repo for '$USER'"
    indent "$cmd" --batch clone "$repo"
    indent "$cmd" --batch link "$castle"
  fi

  if ! "$cmd" check "$castle"; then
    indent "$cmd" --batch pull "$castle"
    indent "$cmd" --batch link "$castle"
  fi
}

# Prints the latest stable release of Go.
latest_go_version() {
  local version
  version="$(mktemp_file)"
  cleanup_file "$version"

  need_cmd cat

  download "https://golang.org/VERSION?m=text" "$version" >/dev/null
  cat "$version"
}

json_items() {
  local filter='.[] | if type == "object" then .name else . end'

  need_cmd jq

  if [ -n "${1:-}" ]; then
    jq -r "$filter" "$1"
  else
    jq -r "$filter"
  fi
}

install_beets_pip_pkgs() {
  install_pip3_pkg requests
  install_pip3_pkg pylast
  install_pip3_pkg flask
  install_pip3_pkg beets
}
