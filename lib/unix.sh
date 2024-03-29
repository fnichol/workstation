#!/usr/bin/env sh
# shellcheck disable=SC3043

unix_install_chruby() {
  local ver
  ver="$(unix_latest_chruby_version)"

  if check_cmd chruby-exec; then
    local installed_ver
    installed_ver="$(chruby-exec --version | awk '{print $NF}')"
    if [ "$installed_ver" = "$ver" ]; then
      info "Current chruby version '$ver' is installed"
      return 0
    fi
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

  local tar
  tar="$(mktemp_file)"
  cleanup_file "$tar"

  info "Installing chruby $ver"
  download \
    "https://github.com/postmodern/chruby/archive/v${ver}.tar.gz" \
    "$tar"
  tar -xzf "$tar" -C /tmp
  (cd "/tmp/chruby-$ver" && indent "$sudo" make install)
  rm -rf "/tmp/chruby-$ver"
}

unix_install_ruby_install() {
  local ver
  ver="$(unix_latest_ruby_install_version)"

  if check_cmd ruby-install; then
    local installed_ver
    installed_ver="$(ruby-install --version | awk '{print $NF}')"
    if [ "$installed_ver" = "$ver" ]; then
      info "Current ruby-install version '$ver' is installed"
      return 0
    fi
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

  local tar
  tar="$(mktemp_file)"
  cleanup_file "$tar"

  info "Installing ruby-install $ver"
  download \
    "https://github.com/postmodern/ruby-install/archive/v${ver}.tar.gz" \
    "$tar"
  tar -xzf "$tar" -C /tmp
  (cd "/tmp/ruby-install-$ver" && indent "$sudo" make install)
  rm -rf "/tmp/ruby-install-$ver"
}

unix_install_volta() {
  local volta="$1"

  local ver
  ver="$(unix_latest_volta_version)"

  if [ -x "$volta" ]; then
    local installed_ver
    installed_ver="$("$volta" --version)"
    if [ "$installed_ver" = "$ver" ]; then
      info "Current Volta version '$ver' is installed"
      return 0
    fi
  fi

  need_cmd bash

  local install_sh
  install_sh="$(mktemp_file)"
  cleanup_file "$install_sh"

  info "Installing Volta '$ver'"
  download https://get.volta.sh "$install_sh"
  indent bash "$install_sh" --skip-setup
}

unix_latest_chruby_version() {
  unix_latest_git_tag "https://github.com/postmodern/chruby"
}

unix_latest_ruby_install_version() {
  unix_latest_git_tag "https://github.com/postmodern/ruby-install"
}

unix_latest_volta_version() {
  unix_latest_github_release "volta-cli/volta"
}

unix_latest_git_tag() {
  local repo="$1"

  need_cmd awk

  sorted_git_tags "$repo" | awk -F/ '
    ($NF ~ /^v[0-9]+\./ && $NF !~ /\^\{\}$/) { last = $NF }
    END { sub(/^v/, "", last); print last }'
}

unix_latest_github_release() {
  local repo="$1"
  local latest
  latest="$(mktemp_file)"
  cleanup_file "$latest"

  need_cmd jq
  need_cmd sed

  download "https://api.github.com/repos/$repo/releases/latest" \
    "$latest" >/dev/null
  jq -r .tag_name <"$latest" | sed 's/^v//'
}
