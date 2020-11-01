#!/usr/bin/env sh
# shellcheck disable=SC2039

freebsd_set_hostname() {
  local fqdn="$1"

  need_cmd grep

  sudo hostname "$fqdn"

  if grep -q '^hostname=' /etc/rc.conf >/dev/null; then
    need_cmd sed
    sudo sed -i '' "s/^hostname=.*$/hostname=\"$fqdn\"/" /etc/rc.conf
  else
    need_cmd tee
    echo "hostname=\"$fqdn\"" | sudo tee -a /etc/rc.conf >/dev/null
  fi
}

freebsd_setup_package_system() {
  indent sudo pkg update
}

freebsd_update_system() {
  indent sudo pkg upgrade --yes --no-repo-update
}

freebsd_install_base_packages() {
  local data_path="$1"

  install_pkg jq
  install_pkgs_from_json "$data_path/freebsd_base_pkgs.json"
}

freebsd_install_headless_packages() {
  local data_path="$1"

  install_pkgs_from_json "$data_path/freebsd_headless_pkgs.json"
  freebsd_install_beets
}

freebsd_install_node() {
  install_pkg node
  install_pkg npm
}

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
  need_cmd uname

  local release
  release="$(uname -r)"

  case "$release" in
    12.*)
      install_pkg py37-pip
      install_pkg py37-gdbm
      ;;
    11.*)
      install_pkg py36-pip
      install_pkg py36-gdbm
      ;;
    *)
      warn "Installing beets on $release no yet supported, skipping"
      ;;
  esac

  install_pkg ffmpeg

  # TODO: support compiling lame pkg
  # See: fnichol/workstation#15
  # install_pkg lame

  install_beets_pip_pkgs
}
