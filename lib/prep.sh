print_help() {
  cat<<HELP
$_program $_version

$_author

Workstation Setup

USAGE:
        $_program [FLAGS] [OPTIONS] [<FQDN>]

FLAGS:
    -b  Only sets up base system (not extra workstation setup)
    -h  Prints this message

ARGS:
    <FQDN>    The name for this workstation

HELP
}

parse_cli_args() {
  OPTIND=1
  # Parse command line flags and options
  while getopts ":hb" opt; do
    case $opt in
      b)
        _base_only=true
        ;;
      h)
        print_help
        exit 0
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

  local lib_path="${0%/*}/../lib"
  local hostname
  hostname="$(hostname)"

  _system="$(uname -s)"

  _data_path="${0%/*}/../data"

  if [ "$_system" != "Linux" ]; then
    _os="$_system"
  elif [ -f /etc/lsb-release ]; then
    _os="$(. /etc/lsb-release; echo $DISTRIB_ID)"
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
    Linux)
      # shellcheck source=lib/linux.sh
      . "$lib_path/linux.sh"
      ;;
  esac

  header "Setting up workstation '${_argv_hostname:-$hostname}'"

  ensure_not_root
  get_sudo
  keep_sudo

  if [ "$_system" = "Darwin" ]; then
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
        echo "$name" | sudo tee /etc/hostname > /dev/null
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
        echo "$name" | sudo tee /etc/hostname > /dev/null
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
    Arch)
      arch_add_repos
      sudo pacman -Syy --noconfirm | indent
      ;;
    Darwin)
      darwin_install_xcode_cli_tools
      darwin_install_homebrew
      ;;
    RedHat)
      # Nothing to do
      ;;
    Ubuntu)
      sudo apt-get update | indent
      ;;
    *)
      warn "Setting up package system on $_os not yet supported, skipping"
      ;;
  esac
}

update_system() {
  header "Applying system updates"

  case "$_os" in
    Arch)
      sudo pacman -Su --noconfirm | indent
      ;;
    Darwin)
      softwareupdate --install --all 2>&1 | indent
      env HOMEBREW_NO_AUTO_UPDATE=true brew upgrade --cleanup
      ;;
    RedHat)
      # Nothing to do
      ;;
    Ubuntu)
      sudo apt-get -y dist-upgrade | indent
      ;;
    *)
      warn "Setting up package system on $_os not yet supported, skipping"
      ;;
  esac
}

install_base_packages() {
  header "Installing base packages"

  case "$_os" in
    Arch)
      install_pkg jq
      install_pkgs_from_json "$_data_path/arch_base_pkgs.json"
      ;;
    Darwin)
      install_pkg jq
      install_pkgs_from_json "$_data_path/darwin_base_pkgs.json"
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
    Arch)
      # Nothing to do
      ;;
    Darwin)
      darwin_set_preferences "$_data_path/darwin_prefs.json"
      darwin_install_iterm2_settings
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
  sudo bash /tmp/install.sh | indent
  rm -f /tmp/install.sh
}

install_dot_configs() {
  need_cmd cut
  need_cmd git

  local repo
  local repo_dir

  header "Installing dot configs"

  if [ ! -f "$HOME/.homesick/repos/homeshick/homeshick.sh" ]; then
    info "Installing homeshick for '$USER'"
    git clone --depth 1 git://github.com/andsens/homeshick.git \
      "$HOME/.homesick/repos/homeshick" | indent
  fi

  cat "$_data_path/homesick_repos.json" | jq -r .[] | while read -r repo; do
    repo_dir="$HOME/.homesick/repos/$(echo "$repo" | cut -d '/' -f 2)"

    if [ ! -d "$repo_dir" ]; then
      info "Installing repo $repo for '$USER'"
      bash -c ". $HOME/.homesick/repos/homeshick/homeshick.sh \
        && homeshick --batch clone $repo" 2>&1 | indent
    fi
  done

  info "Updating dotfile configurations links for '$USER'"
  bash -c ". $HOME/.homesick/repos/homeshick/homeshick.sh \
    && homeshick --force link" 2>&1 | indent
}

install_workstation_packages() {
  header "Installing workstation packages"

  case "$_os" in
    Arch)
      install_pkgs_from_json "$_data_path/arch_workstation_pkgs.json"
      ;;
    Darwin)
      darwin_add_homebrew_taps
      darwin_install_cask_pkgs_from_json "$_data_path/darwin_cask_pkgs.json"
      darwin_install_apps_from_json "$_data_path/darwin_apps.json"
      install_pkgs_from_json "$_data_path/darwin_workstation_pkgs.json"
      killall Dock
      killall Finder
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

install_rust() {
  local rustc="$HOME/.cargo/bin/rustc"
  local cargo="$HOME/.cargo/bin/cargo"

  header "Setting up Rust"

  if [ ! -x "$rustc" ]; then
    need_cmd curl

    info "Installing Rust"
    curl -sSf https://sh.rustup.rs \
      | sh -s -- -y --default-toolchain stable 2>&1 \
      | indent
    "$rustc" --version | indent
    "$cargo" --version | indent
  fi

  if ! "$cargo" install --list | grep -q rustfmt; then
    info "Installing rustfmt"
    "$cargo" install rustfmt 2>&1 | indent
  fi
}

install_ruby() {
  header "Setting up Ruby"

  case "$_system" in
    Darwin)
      install_pkg chruby
      install_pkg ruby-install
      ;;
    Linux)
      linux_install_chruby
      linux_install_ruby_install
      ;;
    *)
      warn "Installing Ruby on $_os not yet supported, skipping"
      return 0
      ;;
  esac

  # shellcheck disable=SC2012
  if [ "$(ls -1 "$HOME/.rubies" 2> /dev/null | wc -l)" -eq 0 ]; then
    info "Building curent stable version of Ruby"
    ruby-install --cleanup --src-dir /tmp/ruby-src ruby 2>&1
  fi

  sudo mkdir -p /etc/profile.d

  if [ ! -f /etc/profile.d/chruby.sh ]; then
    info "Creating /etc/profile.d/chruby.sh"
    cat <<_CHRUBY_ | sudo tee /etc/profile.d/chruby.sh > /dev/null
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

  need_cmd cat
  need_cmd rm
  need_cmd sudo

  local ver
  ver="1.8.3"

  if [ -f /usr/local/go/VERSION ]; then
    local installed_ver
    installed_ver="$(cat /usr/local/go/VERSION)"
    if [ "$installed_ver" = "go${ver}" ]; then
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
    x86_64)
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

  local url version

  if [ ! -f "$HOME/.nvm/nvm.sh" ]; then
    info "Installing nvm"
    version="$(curl -sSf \
      https://api.github.com/repos/creationix/nvm/releases/latest \
      | jq -r .tag_name)"
    url="https://raw.githubusercontent.com/creationix/nvm/$version/install.sh"

    touch "$HOME/.bash_profile"
    curl -sSf "$url" | env PROFILE="$HOME/.bash_profile" bash 2>&1 | indent
  fi

  # shellcheck disable=SC2012
  if [ "$(ls -1 "$HOME/.nvm/versions/node" 2> /dev/null | wc -l)" -eq 0 ]; then
    info "Installing current stable version of Node"
    bash -c '. $HOME/.nvm/nvm.sh && nvm install --lts 2>&1' | indent
  fi
}

finish() {
  header "Finished setting up workstation, enjoy!"
}

install_pkg() {
  case "$_os" in
    Arch)
      arch_install_pkg "$@"
      ;;
    Darwin)
      darwin_install_pkg "$@"
      ;;
    RedHat)
      redhat_install_pkg "$@"
      ;;
    Ubuntu)
      ubuntu_install_pkg "$@"
      ;;
    *)
      warn "Installing package on $_os not yet supported, skipping..."
      ;;
  esac
}

install_pkgs_from_json() {
  need_cmd cat
  need_cmd jq

  local json="$1"

  cat "$json" | jq -r .[] | while read -r pkg; do
    install_pkg "$pkg"
  done
}
