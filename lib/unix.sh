#!/usr/bin/env sh
# shellcheck disable=SC2039

unix_install_chruby() {
  if [ -f /usr/local/share/chruby/chruby.sh ]; then
    return 0
  fi

  need_cmd make
  need_cmd rm
  need_cmd tar
  need_cmd uname

  local sudo
  case "$(uname -s)" in
    OpenBSD)
      need_cmd doas
      sudo="doas"
      ;;
    *)
      need_cmd sudo
      sudo="sudo"
      ;;
  esac

  local version tar
  version="v0.3.9"
  tar="$(mktemp_file)"
  cleanup_file "$tar"

  info "Installing chruby"
  download \
    "https://github.com/postmodern/chruby/archive/${version}.tar.gz" \
    "$tar"
  tar -xzf "$tar" -C /tmp
  (cd "/tmp/chruby-${version#v}" && indent "$sudo" make install)
  rm -rf "/tmp/chruby-${version#v}"
}

unix_install_ruby_install() {
  if [ -f /usr/local/share/ruby-install/ruby-install.sh ]; then
    return 0
  fi

  need_cmd make
  need_cmd rm
  need_cmd tar
  need_cmd uname

  local sudo
  case "$(uname -s)" in
    OpenBSD)
      need_cmd doas
      sudo="doas"
      ;;
    *)
      need_cmd sudo
      sudo="sudo"
      ;;
  esac

  local version tar
  version="v0.7.0"
  tar="$(mktemp_file)"
  cleanup_file "$tar"

  info "Installing ruby-install"
  download \
    "https://github.com/postmodern/ruby-install/archive/${version}.tar.gz" \
    "$tar"
  tar -xzf "$tar" -C /tmp
  (cd "/tmp/ruby-install-${version#v}" && indent "$sudo" make install)
  rm -rf "/tmp/ruby-install-${version#v}"
}
