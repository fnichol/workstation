freebsd_install_pkg() {
  need_cmd pkg

  local pkg="$1"

  if pkg info -e "$pkg" >/dev/null 2>&1; then
    return 0
  fi

  info "Installing package '$pkg'"
  sudo pkg install --yes --no-repo-update "$pkg" 2>&1 | indent
}
