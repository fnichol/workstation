#!/usr/bin/env sh
# shellcheck disable=SC3043

alpine_install_pkg() {
  need_cmd apk
  need_cmd sudo

  local pkg="$1"

  if apk info | grep -q "^${pkg}$" >/dev/null 2>&1; then
    return 0
  fi

  info "Installing package '$pkg'"
  indent sudo apk add "$pkg"
}

redhat_install_jq() {
  install_pkg wget

  if [ ! -f /usr/local/bin/jq ]; then
    local jq_bin
    jq_bin="$(mktemp_file)"
    cleanup_file "$jq_bin"

    info "Installing jq"
    download \
      https://github.com/stedolan/jq/releases/download/jq-1.6/jq-linux64 \
      "$jq_bin"
    sudo cp "$jq_bin" /usr/local/bin/jq
    sudo chmod 0755 /usr/local/bin/jq
  fi
}

redhat_install_pkg() {
  local pkg="$1"

  if sudo yum list installed "$pkg" >/dev/null 2>&1; then
    return 0
  fi

  info "Installing package '$pkg'"
  indent sudo yum install -y "$pkg"
}

ubuntu_install_pkg() {
  local pkg="$1"
  local status

  need_cmd apt-get
  need_cmd dpkg-query
  need_cmd sudo

  # Thanks to https://askubuntu.com/a/668229 for the inspiration
  if status="$(
    dpkg-query --show --showformat='${db:Status-Status}\n' "$pkg" 2>/dev/null
  )"; then
    if [ "$status" = "installed" ]; then
      return 0
    fi
  fi

  info "Installing package '$pkg'"
  indent sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y "$pkg"
}
