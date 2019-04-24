#!/usr/bin/env sh
# shellcheck disable=SC2039

# shellcheck disable=SC2154
print_help() {
  cat <<HELP
$_program $_version

$_author

Workstation Setup

USAGE:
        $_program [FLAGS] [OPTIONS] [<FQDN>]

FLAGS:
    -h  Prints this message
    -W  Skip workstation and X setups
    -X  Skip X setup

ARGS:
    <FQDN>    The name for this workstation

HELP
}

parse_cli_args() {
  OPTIND=1
  # Parse command line flags and options
  while getopts ":hWX" opt; do
    case $opt in
      h)
        print_help
        exit 0
        ;;
      W)
        # shellcheck disable=SC2034
        _skip_workstation=true
        _skip_x=true
        ;;
      X)
        # shellcheck disable=SC2034
        _skip_x=true
        ;;
      \?)
        print_help
        exit_with "Invalid option:  -$OPTARG" 1
        ;;
    esac
  done
  # Shift off all parsed token in `$*` so that the subcommand is now `$1`.
  shift "$((OPTIND - 1))"

  if [ -n "${1:-}" ]; then
    _argv_hostname="$1"
  fi

  if [ "$(uname -s)" = "Darwin" ] \
    && [ "${_base_only:-}" != "true" ] \
    && [ ! -f "$HOME/Library/Preferences/com.apple.appstore.plist" ]; then
    printf -- "Not logged into App Store, please login and try again.\n\n"
    print_help
    exit_with "Must be logged into App Store" 2
  fi
}

init() {
  need_cmd basename
  need_cmd hostname
  need_cmd uname

  # shellcheck disable=SC2154
  local lib_path="$_root/lib"
  local hostname
  hostname="$(hostname)"

  _system="$(uname -s)"

  _data_path="$_root/data"

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
      # shellcheck source=lib/linux.sh
      . "$lib_path/linux.sh"
      # shellcheck source=lib/unix.sh
      . "$lib_path/unix.sh"
      ;;
  esac

  header "Setting up workstation '${_argv_hostname:-$hostname}'"

  ensure_not_root
  get_sudo
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
      need_cmd grep
      need_cmd hostname
      need_cmd sed
      need_cmd sudo
      need_cmd tee

      local old_hostname
      old_hostname="$(hostname -f)"

      if [ "$old_hostname" != "$name" ]; then
        echo "$name" | sudo tee /etc/hostname >/dev/null
        sudo hostname "$name"
        if ! grep -q -w "$fqdn" /etc/hosts; then
          sudo sed -i "1i 127.0.0.1\\t${fqdn}\\t${name}" /etc/hosts
        fi
        if command -v hostnamectl; then
          sudo hostnamectl set-hostname "$name"
        fi
      fi
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
    ssh-keygen \
      -N '' \
      -C "${USER}@$(hostname -f)-$(date +%FT%T%z)" \
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
  need_cmd rm
  need_cmd sudo

  if [ -f /etc/bash/bashrc.local ]; then
    return 0
  fi

  header "Installing fnichol/bashrc"
  download https://raw.githubusercontent.com/fnichol/bashrc/master/contrib/install-system-wide \
    /tmp/install.sh
  indent sudo bash /tmp/install.sh
  rm -f /tmp/install.sh
}

install_dot_configs() {
  need_cmd cut
  need_cmd git
  need_cmd jq

  local repo repo_dir castle

  header "Installing dot configs"

  if [ ! -f "$HOME/.homesick/repos/homeshick/homeshick.sh" ]; then
    info "Installing homeshick for '$USER'"
    indent git clone --depth 1 git://github.com/andsens/homeshick.git \
      "$HOME/.homesick/repos/homeshick"
  fi

  jq -r .[] "$_data_path/homesick_repos.json" | while read -r repo; do
    manage_homesick_repo "$repo"
  done
}

install_workstation_packages() {
  header "Installing workstation packages"

  case "$_os" in
    Alpine)
      install_pkgs_from_json "$_data_path/alpine_workstation_pkgs.json"
      ;;
    Arch)
      install_pkgs_from_json "$_data_path/arch_workstation_pkgs.json"
      ;;
    Darwin)
      darwin_install_cask_pkgs_from_json "$_data_path/darwin_cask_pkgs.json"
      darwin_install_apps_from_json "$_data_path/darwin_apps.json"
      install_pkgs_from_json "$_data_path/darwin_workstation_pkgs.json"
      killall Dock
      killall Finder
      ;;
    FreeBSD)
      install_pkgs_from_json "$_data_path/freebsd_workstation_pkgs.json"
      ;;
    RedHat)
      install_pkgs_from_json "$_data_path/redhat_workstation_pkgs.json"
      ;;
    Ubuntu)
      install_pkgs_from_json "$_data_path/ubuntu_workstation_pkgs.json"
      ;;
    *)
      warn "Installing packages on $_os not yet supported, skipping"
      ;;
  esac
}

install_habitat() {
  header "Installing Habitat"

  if command -v hab >/dev/null; then
    return 0
  fi

  local url="https://raw.githubusercontent.com/habitat-sh/habitat/master/components/hab/install.sh"

  case "$_os" in
    Darwin)
      curl -sSf "$url" | indent sh
      ;;
    FreeBSD)
      info "Habitat not yet supported on FreeBSD"
      return 0
      ;;
    *)
      curl -sSf "$url" | indent sudo sh
      ;;
  esac
}

install_rust() {
  local rustc="$HOME/.cargo/bin/rustc"
  local cargo="$HOME/.cargo/bin/cargo"
  local rustup="$HOME/.cargo/bin/rustup"
  local installed_plugins

  header "Setting up Rust"

  if [ "$_os" = Alpine ]; then
    warn "Alpine Linux not supported, skipping Rust installation"
    return 0
  fi

  if [ ! -x "$rustc" ]; then
    need_cmd curl

    info "Installing Rust"
    curl -sSf https://sh.rustup.rs \
      | indent sh -s -- -y --default-toolchain stable 2>&1
    indent "$rustc" --version
    indent "$cargo" --version
  fi

  indent "$rustup" self update
  indent "$rustup" update

  indent "$rustup" component add rust-src
  indent "$rustup" component add rustfmt

  installed_plugins="$("$cargo" install --list | grep ':$' | cut -d ' ' -f 1)"
  for plugin in cargo-watch cargo-edit cargo-outdated; do
    if ! echo "$installed_plugins" | grep -q "^$plugin\$"; then
      info "Installing $plugin"
      indent "$cargo" install "$plugin"
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

  if [ "$(find "$HOME/.rubies" -depth 1 | wc -l)" -eq 0 ]; then
    info "Building curent stable version of Ruby"
    ruby-install --cleanup --src-dir /tmp/ruby-src ruby 2>&1
  fi

  sudo mkdir -p /etc/profile.d

  if [ ! -f /etc/profile.d/chruby.sh ]; then
    info "Creating /etc/profile.d/chruby.sh"
    cat <<_CHRUBY_ | sudo tee /etc/profile.d/chruby.sh >/dev/null
source /usr/local/share/chruby/chruby.sh
source /usr/local/share/chruby/auto.sh
_CHRUBY_
  fi

  if [ ! -f /etc/profile.d/renv.sh ]; then
    info "Creating /etc/profile.d/renv.sh"
    download https://raw.githubusercontent.com/fnichol/renv/master/renv.sh \
      /tmp/renv.sh
    sudo cp /tmp/renv.sh /etc/profile.d/renv.sh
    rm -f /tmp/renv.sh
  fi
}

install_go() {
  header "Setting up Go"

  if [ "$_os" = Alpine ]; then
    warn "Alpine Linux not supported, skipping Go installation"
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

  local arch
  local kernel
  local machine
  local url
  kernel="$(uname -s | tr '[:upper:]' '[:lower:]')"
  machine="$(uname -m)"

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

  url="https://storage.googleapis.com/golang/go${ver}.${kernel}-${arch}.tar.gz"

  info "Installing Go $ver"
  sudo mkdir -p /usr/local
  download "$url" "/tmp/$(basename "$url")"
  sudo tar xf "/tmp/$(basename "$url")" -C /usr/local
  rm -f "/tmp/$(basename "$url")"
}

install_node() {
  need_cmd bash
  need_cmd curl
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

  local url version

  if [ ! -f "$HOME/.nvm/nvm.sh" ]; then
    info "Installing nvm"
    version="$(curl -sSf \
      https://api.github.com/repos/creationix/nvm/releases/latest \
      | jq -r .tag_name)"
    url="https://raw.githubusercontent.com/creationix/nvm/$version/install.sh"

    touch "$HOME/.bash_profile"
    curl -sSf "$url" | indent env PROFILE="$HOME/.bash_profile" bash
  fi

  if [ "$(find "$HOME/.nvm/versions/node" -depth 1 | wc -l)" -eq 0 ]; then
    info "Installing current stable version of Node"
    # shellcheck disable=SC2016
    indent bash -c '. $HOME/.nvm/nvm.sh && nvm install --lts 2>&1'
  fi
}

install_x_packages() {
  header "Installing X workstation packages"

  case "$_os" in
    Alpine)
      # Nothing to do yet
      ;;
    Arch)
      arch_build_yay
      install_pkgs_from_json "$_data_path/arch_x_pkgs.json"
      arch_install_aur_pkgs_from_json "$_data_path/arch_aur_pkgs.json"
      if [ "$(cat /sys/class/dmi/id/product_name)" = "XPS 13 9370" ]; then
        # Support customizing touchpad on Dell XPS 13-inch 9370
        install_pkg libinput
        install_pkg xf86-input-libinput
        install_pkg xorg-xinput
      fi
      ;;
    Darwin)
      # TODO fn: factor out macOS packages
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
      warn "Installing packages on $_os not yet supported, skipping"
      ;;
  esac
}

install_x_dot_configs() {
  local repo

  need_cmd jq

  header "Installing X dot configs"

  jq -r .[] "$_data_path/homesick_x_repos.json" | while read -r repo; do
    manage_homesick_repo "$repo"
  done
}

finalize_x_setup() {
  header "Finalizing X setup"

  case "$_os" in
    Alpine)
      # Nothing to do yet
      ;;
    Arch)
      need_cmd ln
      need_cmd sudo

      sudo ln -snf /etc/fonts/conf.avail/11-lcdfilter-default.conf \
        /etc/fonts/conf.d
      sudo ln -snf /etc/fonts/conf.avail/10-sub-pixel-rgb.conf \
        /etc/fonts/conf.d
      sudo ln -snf /etc/fonts/conf.avail/30-infinality-aliases.conf \
        /etc/fonts/conf.d

      if [ "$(cat /sys/class/dmi/id/product_name)" = "XPS 13 9370" ]; then
        need_cmd cut
        need_cmd getent
        need_cmd grep

        # Battery status
        install_pkg acpi

        # Setup power management
        install_pkg powertop
        if [ ! -f /etc/systemd/system/powertop.service ]; then
          need_cmd systemctl

          info "Setting up Powertop for power management tuning"
          cat <<'_EOF_' | sudo tee /etc/systemd/system/powertop.service >/dev/null
[Unit]
Description=Powertop tunings

[Service]
ExecStart=/usr/bin/powertop --auto-tune
RemainAfterExit=true

[Install]
WantedBy=multi-user.target
_EOF_
          sudo systemctl enable powertop
          sudo systemctl start powertop
        fi

        if [ ! -f /etc/udev/rules.d/backlight.rules ]; then
          info "Setting up udev backlight rule"
          cat <<'_EOF_' | sudo tee /etc/udev/rules.d/backlight.rules >/dev/null
ACTION=="add", SUBSYSTEM=="backlight", KERNEL=="intel_backlight", RUN+="/bin/chgrp video /sys/class/backlight/%k/brightness"
ACTION=="add", SUBSYSTEM=="backlight", KERNEL=="intel_backlight", RUN+="/bin/chmod g+w /sys/class/backlight/%k/brightness"
_EOF_
        fi

        if ! getent group video | cut -d : -f 4 | grep -q "$USER"; then
          need_cmd sudo
          need_cmd usermod

          info "Adding $USER to the video group"
          sudo usermod --append --groups video "$USER"
        fi

        arch_install_aur_pkg light
      fi
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
      warn "Finalizing X setup on $_os not yet supported, skipping"
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

install_pkgs_from_json() {
  need_cmd jq

  local json="$1"
  local cache
  cache="$(mktemp_file pkgcache)"
  cleanup_file "$cache"
  # Ensure no file exists
  rm -f "$cache"

  jq -r .[] "$json" | while read -r pkg; do
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

  git ls-remote --tags --sort=version:refname https://go.googlesource.com/go \
    | awk -F/ '
      ($NF ~ /^go[0-9]+\./ && $NF !~ /(beta|rc)[0-9]+$/) { last = $NF }
      END { sub(/^go/, "", last); print last }'
}
