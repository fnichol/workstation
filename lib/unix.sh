#!/usr/bin/env sh
# shellcheck disable=SC2039

unix_install_chruby() {
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
  (cd "/tmp/chruby-${version#v}" && indent sudo make install)
  rm -rf "/tmp/chruby-${version#v}" "/tmp/chruby-${version#v}.tar.gz"
}

unix_install_ruby_install() {
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
  (cd "/tmp/ruby-install-${version#v}" && indent sudo make install)
  rm -rf "/tmp/ruby-install-${version#v}" "/tmp/ruby-install-${version#v}.tar.gz"
}
