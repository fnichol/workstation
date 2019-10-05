#!/usr/bin/env sh
# shellcheck disable=SC2039

freebsd_install_pkg() {
  need_cmd pkg

  local pkg="$1"

  if pkg info -e "$pkg" >/dev/null 2>&1; then
    return 0
  fi

  info "Installing package '$pkg'"
  indent sudo pkg install --yes --no-repo-update "$pkg"
}

freebsd_install_beets() {
  install_pkg py36-pip
  install_pkg py36-gdbm
  install_pkg ffmpeg
  install_pkg lame

  install_beets_pip_pkgs
}
