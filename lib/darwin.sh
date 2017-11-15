darwin_check_tmux() {
  if [ -n "${TMUX:-}" ]; then
    warn "$_program must not be run under tmux for mas to work correctly."
    exit_with "Program run under tmux session" 1
  fi
}

# Implementation graciously borrowed and modified from the build-essential
# Chef cookbook which has been graciously borrowed and modified from Tim
# Sutton's osx-vm-templates project.
#
# Source: https://github.com/chef-cookbooks/build-essential/blob/a4f9621020e930a0e4fa0ccb5b7957dbef8ab347/libraries/xcode_command_line_tools.rb#L182-L188
# Source: https://github.com/timsutton/osx-vm-templates/blob/b001475df54a9808d3d56d06e71b8fa3001fff42/scripts/xcode-cli-tools.sh
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
  need_cmd touch
  need_cmd tr

  local product

  info "Installing Xcode CLI Tools"

  # Create the placeholder file that's checked by the CLI Tools update .dist
  # code in Apple's SUS catalog
  touch /tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress
  # Find the CLI Tools update
  product="$(softwareupdate -l \
    | grep "\*.*Command Line" \
    | head -n 1 \
    | awk -F"*" '{print $2}' \
    | sed -e 's/^ *//' \
    | tr -d '\n')"
  # Install the update
  softwareupdate -i "$product" --verbose | indent
  # Remove the placeholder to prevent perpetual appearance in the update
  # utility
  rm -f /tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress
}

darwin_install_homebrew() {
  if ! command -v brew >/dev/null; then
    need_cmd ruby

    local url="https://raw.githubusercontent.com/Homebrew/install/master/install"

    info "Installing Homebrew"
    ruby -e "$(curl -fsSL "$url")" < /dev/null | indent
  fi

  brew update | indent
}

darwin_install_pkg() {
  need_cmd brew

  local pkg="$1"

  if [ $(brew list --versions $pkg | wc -l) -ne 0 ]; then
    return 0
  fi

  info "Installing package '$pkg'"
  env HOMEBREW_NO_AUTO_UPDATE=true brew install "$pkg" 2>&1 | indent
}

darwin_install_cask_pkg() {
  need_cmd brew
  need_cmd wc

  local pkg="$1"

  if [ $(brew cask list --versions $pkg 2> /dev/null | wc -l) -ne 0 ]; then
    return 0
  fi

  info "Installing cask package '$pkg'"
  env HOMEBREW_NO_AUTO_UPDATE=true brew cask install "$pkg" 2>&1 | indent
}

darwin_install_app() {
  need_cmd cut
  need_cmd grep
  need_cmd mas

  local pkg="$1"
  local id="$2"

  if mas list | cut -d ' ' -f 1 | grep -q "^${id}$"; then
    return 0
  fi

  info "Installing App '$pkg' ($id)"
  mas install "$id" 2>&1 | indent
}

darwin_install_apps_from_json() {
  need_cmd jq

  local app
  local id
  local json="$1"

  install_pkg mas

  if ! mas account | grep -q '@'; then
    exit_with "Not logged into App Store" 16
  fi

  cat "$json" \
      | jq -r '. | to_entries | .[] | @sh "app=\(.key); id=\(.value)"' \
      | while read -r vars; do
    eval "$vars"
    darwin_install_app "$app" "$id"
  done
}

darwin_install_cask_pkgs_from_json() {
  need_cmd jq

  local json="$1"

  cat "$json" | jq -r .[] | while read -r pkg; do
    darwin_install_cask_pkg "$pkg"
  done
}

darwin_add_homebrew_taps() {
  need_cmd brew
  need_cmd grep

  if brew tap | grep -q '^caskroom/fonts$'; then
    return 0
  fi

  brew tap caskroom/fonts 2>&1 | indent
}

darwin_install_iterm2_settings() {
  need_cmd bash
  need_cmd curl

  local plist="$HOME/Library/Preferences/com.googlecode.iterm2.plist"

  if [ -f "$plist" ]; then
    return 0
  fi

  info "Installing iTerm2 settings"
  curl -sSf https://raw.githubusercontent.com/fnichol/macosx-iterm2-settings/master/contrib/install-settings.sh \
    | bash | indent
}

darwin_symlink_macvim() {
  need_cmd ln

  for b in vim view; do
    if [ ! -L "/usr/local/bin/$b" ]; then
      info "Symlinking /usr/local/bin/$b to /usr/local/bin/mvim"
      { cd /usr/local/bin && ln -s mvim "$b"; }
    fi
  done
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
