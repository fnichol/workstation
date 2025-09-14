#!/usr/bin/env sh
# shellcheck disable=SC3043

darwin_check_tmux() {
  if [ -n "${TMUX:-}" ]; then
    # shellcheck disable=SC2154
    warn "Program must not be run under tmux for mas to work correctly."
    die "Program run under tmux session"
  fi
}

darwin_set_hostname() {
  need_cmd sudo
  need_cmd scutil
  need_cmd defaults

  local name="$1"
  local fqdn="$2"

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
}

darwin_setup_package_system() {
  darwin_install_xcode_cli_tools
  darwin_install_rosetta
  darwin_install_homebrew
}

darwin_update_system() {
  indent softwareupdate --install --all
  indent env HOMEBREW_NO_AUTO_UPDATE=true brew upgrade
  indent env HOMEBREW_NO_AUTO_UPDATE=true brew upgrade --cask
}

darwin_install_base_packages() {
  local data_path="$1"

  install_pkg jq
  install_pkgs_from_json "$data_path/darwin_base_pkgs.json"
}

darwin_set_preferences() {
  need_cmd defaults
  need_cmd profiles
  need_cmd sed

  local asset_path="$1"

  info "Enable screen saver hot corner (bottom left)"
  defaults write com.apple.dock wvous-bl-corner -int 5

  info "Disable screen saver hot corner (top right)"
  defaults write com.apple.dock wvous-tr-corner -int 6

  info "Automatically show and hide the Dock"
  defaults write com.apple.dock autohide -bool true

  info "Remove the Dock autohide animation"
  defaults write com.apple.dock "autohide-time-modifier" -float "0"

  info "Set icon size of Dock images"
  defaults write com.apple.dock tilesize -int 34

  info "Set large icon size of Dock images"
  defaults write com.apple.dock largesize -float 44

  info "Enable Dock magnification"
  defaults write com.apple.dock magnification -bool true

  info "Disable recent apps in the Dock"
  defaults write com.apple.dock show-recents -bool false

  info "Enable password immediately after screen saver starts"
  local domain=com.fnichol
  local organization=fnichol
  local askForPasswordDelay=0
  local config
  config="$(mktemp_file)"
  cleanup_file "$config"
  # shellcheck disable=SC2154
  sed \
    -e "s,{{domain}},$domain,g" \
    -e "s,{{organization}},$organization,g" \
    -e "s,{{askForPasswordDelay}},$askForPasswordDelay,g" \
    "$asset_path/askforpassworddelay.mobileconfig" \
    >"$config"
  profiles -I -F "$config"

  info "Disable press-and-hold for keys in favor of key repeat"
  defaults write NSGlobalDomain ApplePressAndHoldEnabled -bool false

  info "Set a blazingly fast keyboard repeat rate"
  defaults write NSGlobalDomain KeyRepeat -int 1
  defaults write NSGlobalDomain InitialKeyRepeat -int 10

  info "Enable full keyboard access for all controls"
  defaults write NSGlobalDomain AppleKeyboardUIMode -int 3

  info "Disable annoying UI error sounds."
  defaults write com.apple.systemsound com.apple.sound.beep.volume -int 0
  defaults write com.apple.sound.beep feedback -int 0
  defaults write com.apple.systemsound com.apple.sound.uiaudio.enabled -int 0

  info "Set the menu bar date format"
  defaults write com.apple.menuextra.clock DateFormat -string "HH:mm::ss"
  defaults write com.apple.menuextra.clock FlashDateSeparators -bool false
  defaults write com.apple.menuextra.clock IsAnalog -bool false
  defaults write com.apple.menuextra.clock ShowAMPM -bool true
  defaults write com.apple.menuextra.clock Show24Hour -bool true
  defaults write com.apple.menuextra.clock ShowSeconds -bool true
  defaults write com.apple.menuextra.clock ShowDayOfWeek -bool false

  info "Announce time on the hour"
  defaults write com.apple.speech.synthesis.general.prefs \
    TimeAnnouncementPrefs -dict \
    TimeAnnouncementsEnabled -bool true \
    TimeAnnouncementsIntervalIdentifier -string "EveryHourInterval" \
    TimeAnnouncementsPhraseIdentifier -string "ShortTime"

  info "Save to disk (not to iCloud) by default"
  defaults write NSGlobalDomain NSDocumentSaveNewDocumentsToCloud -bool false

  info "Expand Save panel by default"
  defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode -bool true
  defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode2 -bool true

  info "Expand Print panel by default"
  defaults write NSGlobalDomain PMPrintingExpandedStateForPrint -bool true
  defaults write NSGlobalDomain PMPrintingExpandedStateForPrint2 -bool true

  info "Save screenshots to the desktop"
  defaults write com.apple.screencapture location -string "\$HOME/Desktop"

  info "Save screenshots in PNG format"
  defaults write com.apple.screencapture type -string "png"

  info "Disable shadow in screenshots"
  defaults write com.apple.screencapture disable-shadow -bool true

  info "Show all filename extensions in Finder"
  defaults write NSGlobalDomain AppleShowAllExtensions -bool true

  info "Avoid creating .DS_Store files on network volumes"
  defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true

  info "Avoid creating .DS_Store files on USB volumes"
  defaults write com.apple.desktopservices DSDontWriteUSBStores -bool true

  info "Check for software updates daily"
  defaults write com.apple.SoftwareUpdate ScheduleFrequency -int 1

  info "Show icons for external hard drives on the Desktop"
  defaults write com.apple.finder ShowExternalHardDrivesOnDesktop -bool true

  info "Show icons for servers on the Desktop"
  defaults write com.apple.finder ShowMountedServersOnDesktop -bool true

  info "Show icons for removable media on the Desktop"
  defaults write com.apple.finder ShowRemovableMediaOnDesktop -bool true

  info "Show Finder status bar"
  defaults write com.apple.finder ShowStatusBar -bool true

  info "Disable warning when changing a file extension"
  defaults write com.apple.finder FXEnableExtensionChangeWarning -bool false

  info "Use list view in all Finder windows by default"
  defaults write com.apple.finder FXPreferredViewStyle -string "Nlsv"

  info "Empty trash securely by default"
  defaults write com.apple.finder EmptyTrashSecurely -bool true

  info "Disable crash reporter."
  defaults write com.apple.CrashReporter DialogType none

  info "Disable smart dashes"
  defaults write NSGlobalDomain NSAutomaticDashSubstitutionEnabled -bool false

  info "Use all function keys as function keys by default"
  defaults write -g com.apple.keyboard.fnState -bool true

  info "Remove animation for switching between spaces"
  defaults write com.apple.Accessibility ReduceMotionEnabled -int 1
  defaults write com.apple.universalaccess reduceMotion -int 1

  info "Disable rearranging of spaces"
  defaults write com.apple.dock "mru-spaces" -int 0
}

darwin_finalize_base_setup() {
  darwin_set_bash_shell
  darwin_install_terminfo_entries
}

darwin_finalize_headless_setup() {
  need_cmd brew

  local src dst
  src="$(brew --prefix)/opt/openjdk/libexec/openjdk.jdk"
  dst=/Library/Java/JavaVirtualMachines/openjdk.jdk

  if [ -d "$src" ] && [ ! -L "$dst" ]; then
    info "Symlinking OpenJDK to $dst"
    need_cmd ln
    sudo ln -snf "$src" "$dst"
  fi
}

darwin_finalize_graphical_setup() {
  return 0
}

darwin_install_headless_packages() {
  local data_path="$1"

  darwin_add_homebrew_taps_from_json "$data_path/homebrew_headless_taps.json"
  install_pkgs_from_json "$data_path/darwin_headless_pkgs.json"
  darwin_install_cask_pkgs_from_json "$data_path/darwin_headless_cask_pkgs.json"
  darwin_install_beets
}

darwin_install_graphical_packages() {
  local data_path="$1"

  darwin_add_homebrew_taps_from_json "$data_path/homebrew_graphical_taps.json"
  install_pkgs_from_json "$data_path/darwin_graphical_pkgs.json"
  darwin_install_cask_pkgs_from_json "$data_path/darwin_graphical_cask_pkgs.json"
  if [ "$(sysctl -n kern.hv_vmm_present)" = "0" ]; then
    darwin_install_apps_from_json "$data_path/darwin_graphical_apps.json"
  fi
  killall Dock
  killall Finder
}

# Implementation graciously borrowed and modified from the build-essential Chef
# cookbook which has been graciously borrowed and modified from Tim Sutton's
# osx-vm-templates project. Newer fallback case (which sadly seems to be the
# new default) is from Homebrew's `install.sh`
#
# Source: https://github.com/chef-cookbooks/build-essential/blob/a4f9621020e930a0e4fa0ccb5b7957dbef8ab347/libraries/xcode_command_line_tools.rb#L182-L188
# Source: https://github.com/timsutton/osx-vm-templates/blob/d029e89e04871b6c7a6c1cd0ec5beb7fa976f345/scripts/xcode-cli-tools.sh
# Source: https://github.com/Homebrew/install/blob/c017ced9ca817138cc03acabb59454a0a0ca889e/install.sh#L870-L878
darwin_install_xcode_cli_tools() {
  if [ -e "/Library/Developer/CommandLineTools/usr/bin/git" ]; then
    return 0
  fi

  need_cmd awk
  need_cmd grep
  need_cmd head
  need_cmd rm
  need_cmd sed
  need_cmd softwareupdate
  need_cmd sudo
  need_cmd touch
  need_cmd tr
  need_cmd /usr/bin/xcode-select

  local product

  info "Installing Xcode Command Line Tools"

  # Create the placeholder file that's checked by the CLI Tools update .dist
  # code in Apple's SUS catalog
  touch /tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress
  # Find the CLI Tools update
  product="$(softwareupdate --list \
    | sed -n 's/.*Label: \(Command Line Tools for Xcode-.*\)/\1/p' \
    | tail -n 1)"
  if [ -n "$product" ]; then
    # Install the update
    indent softwareupdate -i "$product" --verbose
    sudo /usr/bin/xcode-select --switch /Library/Developer/CommandLineTools
  fi
  # Remove the placeholder to prevent perpetual appearance in the update
  # utility
  rm -f /tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress

  if [ -z "$product" ]; then
    info "Installing Command Line Tools via GUI (sorry!)"
    sudo /usr/bin/xcode-select --install
    echo
    info "Press 'Enter' when the installation is completed"
    echo
    read -r _wait
    sudo /usr/bin/xcode-select --switch /Library/Developer/CommandLineTools
  fi
}

darwin_install_rosetta() {
  # shellcheck disable=2154
  if [ "$_arch" = "arm64" ]; then
    if ! pgrep oahd >/dev/null 2>&1; then
      info "Installing Rosetta 2 on Apple silicon"
      /usr/sbin/softwareupdate --install-rosetta --agree-to-license
    fi
  fi
}

darwin_install_homebrew() {
  if ! command -v brew >/dev/null; then
    need_cmd bash

    local install_sh
    install_sh="$(mktemp_file)"
    cleanup_file "$install_sh"

    info "Installing Homebrew"
    download \
      https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh \
      "$install_sh"
    indent bash "$install_sh" </dev/null
  fi

  indent brew update
}

darwin_install_pkg() {
  need_cmd basename
  need_cmd brew
  need_cmd cut
  need_cmd wc

  local pkg extra_args
  pkg="$(basename "$1" | cut -d' ' -f 1)"
  extra_args="$(basename "$1" | cut -d' ' -f 2-)"
  if [ "$pkg" = "$extra_args" ]; then
    extra_args=""
  fi

  if [ -n "${2:-}" ]; then
    need_cmd grep

    # Cache file was provided
    local cache="$2"

    if [ ! -f "$cache" ]; then
      # If cache file doesn't exist, then populate it
      brew list --versions >"$cache"
    fi

    if grep -E -q "^$pkg\s+" "$cache"; then
      # If an installed package was found in the cache, early return
      return 0
    else
      # About to install a package, so invalidate cache to ensure it is
      # repopulated on next call
      rm -f "$cache"
    fi
  elif [ "$(brew list --versions "$pkg" | wc -l)" -ne 0 ]; then
    # No cache file, but an installed package was found, so early return
    return 0
  fi

  if [ -n "$extra_args" ]; then
    info "Installing package '$pkg' ($extra_args)"
    # shellcheck disable=2086
    indent env HOMEBREW_NO_AUTO_UPDATE=true brew install \
      "$pkg" $extra_args </dev/null
  else
    info "Installing package '$pkg'"
    indent env HOMEBREW_NO_AUTO_UPDATE=true brew install "$pkg" </dev/null
  fi
}

darwin_install_cask_pkg() {
  need_cmd basename
  need_cmd brew
  need_cmd cut
  need_cmd wc

  local pkg pkg_name extra_args
  pkg="$(echo "$1" | cut -d' ' -f 1)"
  pkg_name="$(basename "$1" | cut -d' ' -f 1)"
  extra_args="$(basename "$1" | cut -d' ' -f 2-)"
  if [ "$pkg_name" = "$extra_args" ]; then
    extra_args=""
  fi

  if [ -n "${2:-}" ]; then
    need_cmd grep

    # Cache file was provided
    local cache="$2"

    if [ ! -f "$cache" ]; then
      # If cache file doesn't exist, then populate it
      brew list --cask --versions >"$cache"
    fi

    if grep -E -q "^$pkg_name\s+" "$cache"; then
      # If an installed package was found in the cache, early return
      return 0
    else
      # About to install a package, so invalidate cache to ensure it is
      # repopulated on next call
      rm -f "$cache"
    fi
  elif [ "$(brew cask list --versions "$pkg_name" | wc -l)" -ne 0 ]; then
    # No cache file, but an installed package was found, so early return
    return 0
  fi

  if [ -n "$extra_args" ]; then
    info "Installing cask package '$pkg' ($extra_args)"
    # shellcheck disable=2086
    indent env HOMEBREW_NO_AUTO_UPDATE=true brew install \
      "$pkg" $extra_args </dev/null
  else
    info "Installing cask package '$pkg'"
    indent env HOMEBREW_NO_AUTO_UPDATE=true brew install "$pkg" </dev/null
  fi
}

darwin_install_app() {
  need_cmd cut
  need_cmd grep
  need_cmd mas

  local pkg="$1"
  local id="$2"

  if [ -n "${3:-}" ]; then
    # Cache file was provided
    local cache="$3"

    if [ ! -f "$cache" ]; then
      # If cache file doesn't exist, then populate it
      mas list | cut -d ' ' -f 1 >"$cache"
    fi

    if grep -E -q "^${id}$" "$cache"; then
      # If an installed package was found in the cache, early return
      return 0
    else
      # About to install a package, so invalidate cache to ensure it is
      # repopulated on next call
      rm -f "$cache"
    fi
  elif mas list | cut -d ' ' -f 1 | grep -q "^${id}$"; then
    # No cache file, but an installed package was found, so early return
    return 0
  fi

  info "Installing App '$pkg' ($id)"
  indent mas install "$id"
}

darwin_add_homebrew_tap() {
  need_cmd brew
  need_cmd grep

  local tap="$1"

  if [ -n "${2:-}" ]; then
    # Cache file was provided
    local cache="$2"

    if [ ! -f "$cache" ]; then
      # If cache file doesn't exist, then populate it
      brew tap >"$cache"
    fi

    if grep -E -q "^$tap$" "$cache"; then
      # If an tap was found in the cache, early return
      return 0
    else
      # About to add a tap, so invalidate cache to ensure it is
      # repopulated on next call
      rm -f "$cache"
    fi
  elif brew tap | grep -E -q "^$tap$"; then
    # No cache file, but a tap was found, so early return
    return 0
  fi

  info "Adding homebrew tap '$tap'"
  indent env HOMEBREW_NO_AUTO_UPDATE=true brew tap "$tap"
}

darwin_install_apps_from_json() {
  need_cmd awk
  need_cmd jq
  need_cmd sw_vers

  local ver_maj
  local app
  local id
  local json="$1"
  local cache
  cache="$(mktemp_file)"
  cleanup_file "$cache"
  # Ensure no file exists
  rm -f "$cache"

  install_pkg mas

  ver_maj="$(sw_vers -productVersion | awk -F. '{ print $1 }')"

  if [ "$ver_maj" -lt 12 ]; then
    if ! mas account | grep -q '@'; then
      die "Not logged into App Store"
    fi
  fi

  jq -r '. | to_entries | .[] | @sh "app=\(.key); id=\(.value)"' "$json" \
    | while read -r vars; do
      eval "$vars"
      darwin_install_app "$app" "$id" "$cache"
    done
}

darwin_install_cask_pkgs_from_json() {
  local json="$1"
  local cache
  cache="$(mktemp_file)"
  cleanup_file "$cache"
  # Ensure no file exists
  rm -f "$cache"

  json_items "$json" | while read -r pkg; do
    darwin_install_cask_pkg "$pkg" "$cache"
  done
}

darwin_add_homebrew_taps_from_json() {
  local json="$1"
  local cache
  cache="$(mktemp_file)"
  cleanup_file "$cache"
  # Ensure no file exists
  rm -f "$cache"

  json_items "$json" | while read -r tap; do
    darwin_add_homebrew_tap "$tap" "$cache"
  done
}

darwin_install_beets() {
  install_pkg python
  install_pkg ffmpeg
  install_pkg lame

  install_beets_pip_pkgs
}

darwin_set_bash_shell() {
  need_cmd brew
  need_cmd chsh
  need_cmd cut
  need_cmd dscacheutil
  need_cmd grep

  local bash_shell
  bash_shell="$(brew --prefix)/bin/bash"

  if ! grep -q "^${bash_shell}$" /etc/shells; then
    info "Adding '$bash_shell' to /etc/shells"
    echo "$bash_shell" | sudo tee -a /etc/shells >/dev/null
  fi

  local current_shell
  current_shell="$(dscacheutil -q user -a name "$USER" | grep ^shell: \
    | cut -d' ' -f 2)"

  if [ "$current_shell" != "$bash_shell" ]; then
    info "Setting '$bash_shell' as default shell for '$USER'"
    indent sudo chsh -s "$bash_shell" "$USER"
  fi
}

# Ensure that common and useful terminfo entries are present on system's
# ncurses database which is old and out-of-date.
#
# See:
# https://gpanders.com/blog/the-definitive-guide-to-using-tmux-256color-on-macos/
darwin_install_terminfo_entries() {
  local entries="alacritty alacritty-direct tmux-256color screen-256color"
  local entry

  need_cmd brew
  need_cmd sudo

  for entry in $entries; do
    if ! /usr/bin/infocmp "$entry" >/dev/null 2>&1; then
      local info
      info="$(mktemp_file)"
      cleanup_file "$info"

      info "Adding '$entry' to terminfo"
      "$(brew --prefix ncurses)/bin/infocmp" -x "$entry" >"$info"
      sudo /usr/bin/tic -x "$info"
    fi
  done
}
