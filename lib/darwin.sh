#!/usr/bin/env sh
# shellcheck disable=SC2039

darwin_check_tmux() {
  if [ -n "${TMUX:-}" ]; then
    # shellcheck disable=SC2154
    warn "$_program must not be run under tmux for mas to work correctly."
    exit_with "Program run under tmux session" 1
  fi
}

# Implementation graciously borrowed and modified from the build-essential
# Chef cookbook which has been graciously borrowed and modified from Tim
# Sutton's osx-vm-templates project.
#
# Source: https://github.com/chef-cookbooks/build-essential/blob/a4f9621020e930a0e4fa0ccb5b7957dbef8ab347/libraries/xcode_command_line_tools.rb#L182-L188
# Source: https://github.com/timsutton/osx-vm-templates/blob/d029e89e04871b6c7a6c1cd0ec5beb7fa976f345/scripts/xcode-cli-tools.sh
darwin_install_xcode_cli_tools() {
  need_cmd pkgutil

  if pkgutil --pkgs=com.apple.pkg.CLTools_Executables >/dev/null; then
    return 0
  fi

  need_cmd awk
  need_cmd grep
  need_cmd head
  need_cmd rm
  need_cmd sed
  need_cmd softwareupdate
  need_cmd sw_vers
  need_cmd touch
  need_cmd tr

  local product os_vers

  info "Installing Xcode CLI Tools"

  os_vers="$(sw_vers -productVersion | awk -F. '{print $1"."$2}')"

  # Create the placeholder file that's checked by the CLI Tools update .dist
  # code in Apple's SUS catalog
  touch /tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress
  # Find the CLI Tools update
  product="$(softwareupdate -l \
    | grep "\*.*Command Line" \
    | grep "$os_vers" \
    | tail -n 1 \
    | awk -F"*" '{print $2}' \
    | sed -e 's/^ *//' \
    | tr -d '\n')"
  # Install the update
  indent softwareupdate -i "$product" --verbose
  # Remove the placeholder to prevent perpetual appearance in the update
  # utility
  rm -f /tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress
}

darwin_install_homebrew() {
  if ! command -v brew >/dev/null; then
    need_cmd cat
    need_cmd ruby

    local install_rb
    install_rb="$(mktemp_file)"
    cleanup_file "$install_rb"

    info "Installing Homebrew"
    download \
      https://raw.githubusercontent.com/Homebrew/install/master/install \
      "$install_rb"
    indent ruby -e "$(cat "$install_rb")" </dev/null
  fi

  indent brew update
}

darwin_install_pkg() {
  need_cmd brew
  need_cmd wc

  local pkg="$1"

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

  info "Installing package '$pkg'"
  indent env HOMEBREW_NO_AUTO_UPDATE=true brew install "$pkg"
}

darwin_install_cask_pkg() {
  need_cmd brew
  need_cmd wc

  local pkg="$1"

  if [ -n "${2:-}" ]; then
    need_cmd grep

    # Cache file was provided
    local cache="$2"

    if [ ! -f "$cache" ]; then
      # If cache file doesn't exist, then populate it
      brew cask list --versions >"$cache"
    fi

    if grep -E -q "^$pkg\s+" "$cache"; then
      # If an installed package was found in the cache, early return
      return 0
    else
      # About to install a package, so invalidate cache to ensure it is
      # repopulated on next call
      rm -f "$cache"
    fi
  elif [ "$(brew cask list --versions "$pkg" | wc -l)" -ne 0 ]; then
    # No cache file, but an installed package was found, so early return
    return 0
  fi

  info "Installing cask package '$pkg'"
  indent env HOMEBREW_NO_AUTO_UPDATE=true brew cask install "$pkg"
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
  need_cmd jq

  local app
  local id
  local json="$1"
  local cache
  cache="$(mktemp_file appcache)"
  cleanup_file "$cache"
  # Ensure no file exists
  rm -f "$cache"

  install_pkg mas

  if ! mas account | grep -q '@'; then
    exit_with "Not logged into App Store" 16
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
  cache="$(mktemp_file caskcache)"
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
  cache="$(mktemp_file brewtapcache)"
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

darwin_install_iterm2_settings() {
  need_cmd bash

  local plist="$HOME/Library/Preferences/com.googlecode.iterm2.plist"
  if [ -f "$plist" ]; then
    return 0
  fi

  local install_sh
  install_sh="$(mktemp_file)"
  cleanup_file "$install_sh"

  info "Installing iTerm2 settings"
  download \
    https://raw.githubusercontent.com/fnichol/macosx-iterm2-settings/master/contrib/install-settings.sh \
    "$install_sh"
  indent bash "$install_sh"
}

darwin_set_preferences() {
  need_cmd defaults

  info "Enable screen saver hot corner (bottom left)"
  defaults write com.apple.dock wvous-bl-corner -int 5

  info "Disable screen saver hot corner (top right)"
  defaults write com.apple.dock wvous-tr-corner -int 6

  info "Automatically show and hide the Dock"
  defaults write com.apple.dock autohide -bool true

  info "Set icon size of Dock images"
  defaults write com.apple.dock tilesize -int 34

  info "Set large icon size of Dock images"
  defaults write com.apple.dock largesize -float 44

  info "Enable Dock magnification"
  defaults write com.apple.dock magnification -bool true

  info "Enable password immediately after screen saver starts"
  defaults write com.apple.screensaver askForPassword -int 1
  defaults write com.apple.screensaver askForPasswordDelay -int 0

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
}

darwin_finalize_base_setup() {
  darwin_set_bash_shell
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
