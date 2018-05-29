alpine_install_pkg() {
  need_cmd apk
  need_cmd sudo

  local pkg="$1"

  if apk info | grep -q "^${pkg}$" > /dev/null 2>&1; then
    return 0
  fi

  info "Installing package '$pkg'"
  sudo apk add "$pkg" 2>&1 | indent
}

arch_build_yay() {
  need_cmd pacman

  if pacman -Qi yay > /dev/null 2>&1; then
    return 0
  fi

  install_pkg git

  need_cmd makepkg
  need_cmd mktemp

  local build_dir
  build_dir="$(mktemp -d /tmp/yay.XXXXXXXX)"

  git clone https://aur.archlinux.org/yay.git "$build_dir/yay"
  (cd "$build_dir/yay" && makepkg --syncdeps --install --noconfirm --clean)

  rm -rf "$build_dir"
}

arch_install_pkg() {
  need_cmd pacman

  local pkg="$1"

  if pacman -Qi "$pkg" > /dev/null 2>&1; then
    return 0
  fi

  need_cmd sudo

  info "Installing package '$pkg'"
  sudo pacman -S --noconfirm "$pkg" 2>&1 | indent
}

arch_install_aur_pkg() {
  need_cmd pacman

  local pkg="$1"

  if pacman -Qi "$pkg" > /dev/null 2>&1; then
    return 0
  fi

  need_cmd sudo
  need_cmd yay

  info "Installing package '$pkg'"
  yay -Si -R --noconfirm "$pkg" 2>&1 | indent
}

arch_install_aur_pkgs_from_json() {
  need_cmd jq

  local json="$1"

  cat "$json" | jq -r .[] | while read -r pkg; do
    arch_install_aur_pkg "$pkg"
  done
}

arch_setup_fonts() {
  need_cmd ln
  need_cmd sudo

  sudo ln -svf /etc/fonts/conf.avail/11-lcdfilter-default.conf \
    /etc/fonts/conf.d
  sudo ln -svf /etc/fonts/conf.avail/10-sub-pixel-rgb.conf \
    /etc/fonts/conf.d
  sudo ln -svf /etc/fonts/conf.avail/30-infinality-aliases.conf \
    /etc/fonts/conf.d
}

linux_install_chruby() {
  if [ -f /usr/local/share/chruby/chruby.sh ]; then
    return 0
  fi

  need_cmd make
  need_cmd rm
  need_cmd sudo
  need_cmd tar

  local version url

  info "Installing chruby"
  version="v0.3.9"
  url="https://github.com/postmodern/chruby/archive/${version}.tar.gz"
  download "$url" "/tmp/chruby-${version#v}.tar.gz"
  (cd /tmp && tar -xf "/tmp/chruby-${version#v}.tar.gz")
  (cd "/tmp/chruby-${version#v}" && sudo make install) | indent
  rm -rf "/tmp/chruby-${version#v}" "/tmp/chruby-${version#v}.tar.gz"
}

linux_install_ruby_install() {
  if [ -f /usr/local/share/ruby-install/ruby-install.sh ]; then
    return 0
  fi

  need_cmd make
  need_cmd rm
  need_cmd sudo
  need_cmd tar

  local version url

  info "Installing ruby-install"
  version="v0.6.1"
  url="https://github.com/postmodern/ruby-install/archive/${version}.tar.gz"
  download "$url" "/tmp/ruby-install-${version#v}.tar.gz"
  (cd /tmp && tar -xf "/tmp/ruby-install-${version#v}.tar.gz")
  (cd "/tmp/ruby-install-${version#v}" && sudo make install) | indent
  rm -rf "/tmp/ruby-install-${version#v}" "/tmp/ruby-install-${version#v}.tar.gz"
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

  if sudo yum list installed "$pkg" > /dev/null 2>&1; then
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

  if dpkg -l "$pkg" > /dev/null 2>&1; then
    return 0
  fi

  info "Installing package '$pkg'"
  sudo apt-get install -y "$pkg" 2>&1 | indent
}
