arch_add_repos() {
  if ! grep -q '^\[archlinuxfr\]$' /etc/pacman.conf; then
    info "Adding repository for Yaourt"
    cat <<'EOF' | sudo tee -a /etc/pacman.conf > /dev/null

[archlinuxfr]
SigLevel = Never
Server = http://repo.archlinux.fr/$arch
EOF
  fi
}

arch_install_pkg() {
  need_cmd pacman
  need_cmd sudo

  local pkg="$1"

  if pacman -Qi "$pkg" > /dev/null 2>&1; then
    return 0
  fi

  info "Installing package '$pkg'"
  sudo pacman -S --noconfirm "$pkg" 2>&1 | indent
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
