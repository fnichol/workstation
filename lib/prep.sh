#!/usr/bin/env sh
# shellcheck disable=SC2039

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
                                base-dot-configs, headless-pkgs, rust, ruby,
                                go, node, graphical-pkgs, graphical-dot-configs,
                                graphical-finalize]
        -s, --skip=<T>[,<T>..]  Skip specific tasks
                                [values: hostname, pkg-init, update-system,
                                base-pkgs, preferences, keys, bashrc,
                                base-dot-configs, headless-pkgs, rust, ruby,
                                go, node, graphical-pkgs, graphical-dot-configs,
                                graphical-finalize]

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
          fail "invalid profile name $OPTARG"
          return 1
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
            fail "missing required argument for --$OPTARG option"
            return 1
            ;;
          profile=?*)
            if is_profile_valid "$long_optarg"; then
              profile="$long_optarg"
            else
              print_usage "$program" "$version" "$author" >&2
              fail "invalid profile name '$long_optarg'"
              return 1
            fi
            ;;
          profile*)
            print_usage "$program" "$version" "$author" >&2
            fail "missing required argument for --$OPTARG option"
            return 1
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
            fail "missing required argument for --$OPTARG option"
            return 1
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
            fail "invalid argument --$OPTARG"
            return 1
            ;;
        esac
        ;;
      \?)
        print_usage "$program" "$version" "$author" >&2
        fail "invalid argument; arg=-$OPTARG"
        return 1
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
    print_usage
    exit_with "Must be logged into App Store" 2
  fi

  prepare_workstation "$root" "$profile" "$skips" "$onlys"
}

prepare_workstation() {
  local root="$1"
  local profile="$2"
  local skips="$3"
  local onlys="$4"

  if [ -n "$VERBOSE" ]; then
    echo "root: $root"
    echo "profile: $profile"
    echo "skip: $skips"
    echo "only: $onlys"
  fi

  # Very nice, portable signal handling thanks to:
  # https://unix.stackexchange.com/a/240736
  for sig in HUP INT QUIT ALRM TERM; do
    trap "
      trap_cleanup
      trap - $sig EXIT
      kill -s $sig "'"$$"' "$sig"
  done
  trap trap_cleanup EXIT

  init "$root"
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
      fail "invalid only task: $only"
      return 1
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
      fail "invalid skip task: $skip"
      return 1
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
      bashrc | base-dot-configs | headless-pkgs | rust | ruby | go | node | \
      graphical-pkgs | graphical-dot-configs | graphical-finalize)
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

  local root="$1"
  local lib_path="$root/lib"
  local hostname

  _system="$(uname -s)"

  _data_path="$root/data"

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
      # shellcheck source=lib/darwin.sh
      . "$lib_path/darwin.sh"
      ;;
    FreeBSD)
      # shellcheck source=lib/freebsd.sh
      . "$lib_path/freebsd.sh"
      # shellcheck source=lib/unix.sh
      . "$lib_path/unix.sh"
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

  header "Setting up workstation '${_argv_hostname:-$hostname}'"

  ensure_not_root
  get_sudo "$hostname"
  keep_sudo

  if [ "$_system" = "Darwin" ]; then
    darwin_check_tmux
    # Close any open System Preferences panes, to prevent them from overriding
    # settings we’re about to change
    osascript -e 'tell application "System Preferences" to quit'
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

  header "Setting hostname to '$fqdn'"
  case "$_os" in
    Arch)
      arch_set_hostname "$name" "$fqdn"
      ;;
    Darwin)
      need_cmd sudo
      need_cmd scutil
      need_cmd defaults

      local smb="/Library/Preferences/SystemConfiguration/com.apple.smb.server"
      if [ "$(scutil --get HostName)" != "$fqdn" ]; then
        sudo scutil --set HostName "$fqdn"
      fi
      if [ "$(scutil --get ComputerName)" != "$name" ]; then
        sudo scutil --set ComputerName "$name"
      fi
      if [ "$(scutil --get LocalHostName)" != "$name" ]; then
        sudo scutil --set LocalHostName "$name"
      fi
      if [ "$(defaults read "$smb" NetBIOSName)" != "$name" ]; then
        sudo defaults write "$smb" NetBIOSName -string "$name"
      fi
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
  header "Setting up package system"

  case "$_os" in
    Alpine)
      indent sudo apk update
      ;;
    Arch)
      indent sudo pacman -Syy --noconfirm
      ;;
    Darwin)
      darwin_install_xcode_cli_tools
      darwin_install_homebrew
      ;;
    FreeBSD)
      indent sudo pkg update
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
  header "Applying system updates"

  case "$_os" in
    Alpine)
      indent sudo apk upgrade
      ;;
    Arch)
      indent sudo pacman -Su --noconfirm
      ;;
    Darwin)
      indent softwareupdate --install --all
      indent env HOMEBREW_NO_AUTO_UPDATE=true brew upgrade
      ;;
    FreeBSD)
      indent sudo pkg upgrade --yes --no-repo-update
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
  header "Installing base packages"

  case "$_os" in
    Alpine)
      install_pkg jq
      install_pkgs_from_json "$_data_path/alpine_base_pkgs.json"
      ;;
    Arch)
      install_pkg jq
      install_pkgs_from_json "$_data_path/arch_base_pkgs.json"
      ;;
    Darwin)
      install_pkg jq
      install_pkgs_from_json "$_data_path/darwin_base_pkgs.json"
      ;;
    FreeBSD)
      install_pkg jq
      install_pkgs_from_json "$_data_path/freebsd_base_pkgs.json"
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
  header "Setting preferences"

  case "$_os" in
    Alpine)
      # Nothing to do
      ;;
    Arch)
      # Nothing to do
      ;;
    Darwin)
      darwin_set_preferences "$_data_path/darwin_prefs.json"
      darwin_install_iterm2_settings
      ;;
    FreeBSD)
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
  header "Generating keys"

  need_cmd chmod
  need_cmd date
  need_cmd hostname
  need_cmd mkdir
  need_cmd ssh-keygen

  if [ ! -f "$HOME/.ssh/id_rsa" ]; then
    info "Generating SSH key for '$USER' on this system"
    mkdir -p "$HOME/.ssh"
    indent ssh-keygen \
      -N '' \
      -C "${USER}@$(hostname -f)-$(date -u +%FT%TZ)" \
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
  need_cmd sudo

  if [ -f /etc/bash/bashrc.local ]; then
    header "Updating fnichol/bashrc"
    indent bash -c "source /etc/bash/bashrc && bashrc update"
  else
    local install_sh
    install_sh="$(mktemp_file)"
    cleanup_file "$install_sh"

    header "Installing fnichol/bashrc"
    download \
      https://raw.githubusercontent.com/fnichol/bashrc/master/contrib/install-system-wide \
      "$install_sh"
    info "Running installer"
    indent sudo bash "$install_sh"
  fi

}

install_base_dot_configs() {
  need_cmd cut
  need_cmd git

  local repo repo_dir castle

  header "Installing base dot configs"

  if [ ! -f "$HOME/.homesick/repos/homeshick/homeshick.sh" ]; then
    info "Installing homeshick for '$USER'"
    indent git clone --depth 1 git://github.com/andsens/homeshick.git \
      "$HOME/.homesick/repos/homeshick"
  fi

  json_items "$_data_path/homesick_base_repos.json" | while read -r repo; do
    manage_homesick_repo "$repo"
  done
}

install_headless_packages() {
  header "Installing headless packages"

  case "$_os" in
    Alpine)
      install_pkgs_from_json "$_data_path/alpine_headless_pkgs.json"
      ;;
    Arch)
      arch_install_headless_packages "$_data_path"
      ;;
    Darwin)
      install_pkgs_from_json "$_data_path/darwin_headless_pkgs.json"
      darwin_install_cask_pkgs_from_json "$_data_path/darwin_headless_cask_pkgs.json"
      darwin_install_beets
      ;;
    FreeBSD)
      install_pkgs_from_json "$_data_path/freebsd_headless_pkgs.json"
      freebsd_install_beets
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

  header "Setting up Rust"

  if [ "$_os" = Alpine ]; then
    warn "Alpine Linux not supported, skipping Rust installation"
    return 0
  fi

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

  installed_plugins="$("$cargo" install --list | grep ':$' | cut -d ' ' -f 1)"
  json_items "$_data_path/rust_cargo_plugins.json" | while read -r plugin; do
    if ! echo "$installed_plugins" | grep -q "^$plugin\$"; then
      info "Installing $plugin"
      indent "$cargo" install --verbose "$plugin"
    fi
  done
}

install_ruby() {
  header "Setting up Ruby"

  if [ "$_os" = Alpine ]; then
    warn "Alpine Linux not supported, skipping Ruby installation"
    return 0
  fi

  case "$_system" in
    Darwin)
      install_pkg chruby
      install_pkg ruby-install
      ;;
    FreeBSD)
      unix_install_chruby
      unix_install_ruby_install
      ;;
    Linux)
      unix_install_chruby
      unix_install_ruby_install
      ;;
    *)
      warn "Installing Ruby on $_os not yet supported, skipping"
      return 0
      ;;
  esac

  # Update list of Ruby versions
  indent ruby-install --latest
  # Install latest stable version of Ruby
  indent ruby-install --no-reinstall ruby

  sudo mkdir -p /etc/profile.d

  if [ ! -f /etc/profile.d/chruby.sh ]; then
    info "Creating /etc/profile.d/chruby.sh"
    cat <<_CHRUBY_ | sudo tee /etc/profile.d/chruby.sh >/dev/null
source /usr/local/share/chruby/chruby.sh
source /usr/local/share/chruby/auto.sh
_CHRUBY_
  fi

  if [ ! -f /etc/profile.d/renv.sh ]; then
    local renv_sh
    renv_sh="$(mktemp_file)"
    cleanup_file "$renv_sh"

    info "Creating /etc/profile.d/renv.sh"
    download \
      https://raw.githubusercontent.com/fnichol/renv/master/renv.sh \
      "$renv_sh"
    sudo cp "$renv_sh" /etc/profile.d/renv.sh
  fi
}

install_go() {
  header "Setting up Go"

  if [ "$_os" = Alpine ]; then
    install_pkg "go"
    return 0
  fi

  need_cmd cat
  need_cmd rm
  need_cmd sudo

  # https://golang.org/dl/
  local ver
  ver="$(latest_go_version)"

  if [ -f /usr/local/go/VERSION ]; then
    local installed_ver
    installed_ver="$(cat /usr/local/go/VERSION)"
    if [ "$installed_ver" = "go${ver}" ]; then
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
      exit_with "Installation of Go not currently supported for $machine" 22
      ;;
  esac

  info "Installing Go $ver"
  sudo mkdir -p /usr/local
  download \
    "https://storage.googleapis.com/golang/go${ver}.${kernel}-${arch}.tar.gz" \
    "$tar"
  sudo tar xf "$tar" -C /usr/local
}

install_node() {
  need_cmd bash
  need_cmd env
  need_cmd jq
  need_cmd touch

  header "Setting up Node"

  case "$_os" in
    Alpine)
      warn "Alpine Linux not supported, skipping Node installation"
      return 0
      ;;
    FreeBSD)
      warn "FreeBSD not yet supported, skipping Node installation"
      return 0
      ;;
  esac

  if [ ! -f "$HOME/.nvm/nvm.sh" ]; then
    local api_latest install_sh version
    api_latest="$(mktemp_file)"
    cleanup_file "$api_latest"
    install_sh="$(mktemp_file)"
    cleanup_file "$install_sh"

    info "Installing nvm"
    download \
      https://api.github.com/repos/creationix/nvm/releases/latest \
      "$api_latest"
    version="$(jq -r .tag_name "$api_latest")"

    touch "$HOME/.bash_profile"
    download \
      "https://raw.githubusercontent.com/creationix/nvm/$version/install.sh" \
      "$install_sh"
    indent env PROFILE="$HOME/.bash_profile" bash "$install_sh"
  fi

  # Install latest LTS version of Node
  indent bash -c ". $HOME/.nvm/nvm.sh && nvm install --lts 2>&1"
}

install_graphical_packages() {
  header "Installing graphical packages"

  case "$_os" in
    Alpine)
      # Nothing to do yet
      ;;
    Arch)
      arch_install_graphical_packages "$_data_path"
      ;;
    Darwin)
      darwin_add_homebrew_taps_from_json "$_data_path/homebrew_graphical_taps.json"
      darwin_install_cask_pkgs_from_json "$_data_path/darwin_graphical_cask_pkgs.json"
      darwin_install_apps_from_json "$_data_path/darwin_graphical_apps.json"
      killall Dock
      killall Finder
      ;;
    FreeBSD)
      # Nothing to do yet
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

  header "Installing graphical dot configs"

  json_items "$_data_path/homesick_graphical_repos.json" | while read -r repo; do
    manage_homesick_repo "$repo"
  done
}

finalize_graphical_setup() {
  header "Finalizing graphical setup"

  case "$_os" in
    Alpine)
      # Nothing to do yet
      ;;
    Arch)
      arch_finalize_graphical_setup
      ;;
    Darwin)
      # Nothing to do yet
      ;;
    FreeBSD)
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

finish() {
  header "Finished setting up workstation, enjoy!"
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
      pip_cmd=pip-3.6
      use_sudo=true
      ;;
    *)
      warn "Installing a pip package on $_os not yet supported, skipping..."
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
  cache="$(mktemp_file pkgcache)"
  cleanup_file "$cache"
  # Ensure no file exists
  rm -f "$cache"

  json_items "$json" | while read -r pkg; do
    install_pkg "$pkg" "$cache"
  done
}

manage_homesick_repo() {
  local repo="$1"
  local repo_dir castle

  need_cmd bash
  need_cmd cut

  castle="$(echo "$repo" | cut -d '/' -f 2)"
  repo_dir="$HOME/.homesick/repos/$castle"

  if [ ! -d "$repo_dir" ]; then
    info "Installing repo $repo for '$USER'"
    indent bash -c ". $HOME/.homesick/repos/homeshick/homeshick.sh \
      && homeshick --batch clone $repo"
  fi

  indent bash -c ". $HOME/.homesick/repos/homeshick/homeshick.sh \
    && homeshick --batch pull $castle && homeshick --batch link $castle"
}

# Prints the latest stable release of Go, using the tags from the Git
# sourcetree.
#
# Is it just me, or shouldn't there be a much better way than this??
latest_go_version() {
  need_cmd awk
  need_cmd git

  {
    # The `--sort` option on `git ls-remote` was introduced in Git 2.18.0, so
    # if it's older then we'll have to use GNU/sort's `--version-sort` to help.
    # Oi
    local version
    version="$(git --version | awk '{ print $NF }')"
    if version_ge "$version" 2 18; then
      git ls-remote --tags --sort=version:refname https://go.googlesource.com/go
    else
      need_cmd sort

      git ls-remote --tags https://go.googlesource.com/go \
        | sort --field-separator='/' --key=3 --version-sort
    fi
  } | awk -F/ '
      ($NF ~ /^go[0-9]+\./ && $NF !~ /(beta|rc)[0-9]+$/) { last = $NF }
      END { sub(/^go/, "", last); print last }'
}

version_ge() {
  local version="$1"
  local maj="$2"
  local min="$3"

  [ "$(echo "$version" | awk -F'.' '{ print $1 }')" -ge "$maj" ] \
    && [ "$(echo "$version" | awk -F'.' '{ print $2 }')" -ge "$min" ]
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
