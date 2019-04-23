#!/usr/bin/env sh
# shellcheck disable=SC2039

alpine_install_pkg() {
  need_cmd apk
  need_cmd sudo

  local pkg="$1"

  if apk info | grep -q "^${pkg}$" >/dev/null 2>&1; then
    return 0
  fi

  info "Installing package '$pkg'"
  sudo apk add "$pkg" 2>&1 | indent
}

arch_build_yay() {
  need_cmd pacman

  if pacman -Qi yay >/dev/null 2>&1; then
    return 0
  fi

  need_cmd git
  need_cmd makepkg
  need_cmd mktemp

  local build_dir
  build_dir="$(mktemp -d /tmp/yay.XXXXXXXX)"

  info "Building yay package"
  git clone https://aur.archlinux.org/yay.git "$build_dir/yay"
  (cd "$build_dir/yay" && makepkg --syncdeps --install --noconfirm --clean)

  rm -rf "$build_dir"
}

arch_install_pkg() {
  need_cmd pacman

  local pkg="$1"

  if pacman -Qi "$pkg" >/dev/null 2>&1; then
    # This is a package and it is installed
    return 0
  fi

  if pacman -Qg "$pkg" >/dev/null 2>&1; then
    # This is a package group, so ensure each package is installed
    pacman -Qg "$pkg" \
      | cut -d ' ' -f 2 \
      | while read -r p; do arch_install_pkg "$p" || return 1; done
    return 0
  fi

  need_cmd sudo

  info "Installing package '$pkg'"
  sudo pacman -S --noconfirm "$pkg" 2>&1 | indent
}

arch_install_aur_pkg() {
  need_cmd pacman

  local pkg="$1"

  if pacman -Qi "$pkg" >/dev/null 2>&1; then
    return 0
  fi

  need_cmd sudo
  need_cmd yay

  info "Installing AUR package '$pkg'"
  yay -S --noconfirm "$pkg" 2>&1 | indent
}

arch_install_aur_pkgs_from_json() {
  need_cmd jq

  local json="$1"

  jq -r .[] "$json" | while read -r pkg; do
    arch_install_aur_pkg "$pkg"
  done
}

redhat_install_jq() {
  install_pkg wget

  if [ ! -f /usr/local/bin/jq ]; then
    info "Installing jq"
    download \
      "https://github.com/stedolan/jq/releases/download/jq-1.5/jq-linux64" \
      /tmp/jq
    sudo cp /tmp/jq /usr/local/bin/jq
    sudo chmod 0755 /usr/local/bin/jq
    rm -f /tmp/jq
  fi
}

redhat_install_pkg() {
  local pkg="$1"

  if sudo yum list installed "$pkg" >/dev/null 2>&1; then
    return 0
  fi

  info "Installing package '$pkg'"
  sudo yum install -y "$pkg" 2>&1 | indent
}

ubuntu_install_pkg() {
  need_cmd apt-get
  need_cmd dpkg
  need_cmd sudo

  local pkg="$1"

  if dpkg -l "$pkg" >/dev/null 2>&1; then
    return 0
  fi

  info "Installing package '$pkg'"
  sudo apt-get install -y "$pkg" 2>&1 | indent
}
