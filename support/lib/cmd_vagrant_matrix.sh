#!/usr/bin/env sh
# shellcheck disable=SC3043

# shellcheck source=support/lib/vagrant.sh
. "$ROOT/lib/vagrant.sh"

cmd_vagrant_matrix__for() {
  local distro="$1"
  local version="$2"
  local variant="$3"

  if [ "_" = "$distro" ]; then
    for distro in $(vagrant__distros); do
      _process_distro "$distro" "$version" "$variant"
    done
  else
    _process_distro "$distro" "$version" "$variant"
  fi
}

_process_distro() {
  local distro="$1"
  local version="$2"
  local variant="$3"

  if [ "_" = "$version" ]; then
    for version in $(vagrant__versions_for "$distro"); do
      _process_version "$distro" "$version" "$variant"
    done
  else
    _process_version "$distro" "$version" "$variant"
  fi
}

_process_version() {
  local distro="$1"
  local version="$2"
  local variant="$3"

  if [ "_" = "$variant" ]; then
    for variant in $(vagrant__variants); do
      _print "$distro" "$version" "$variant"
    done
  else
    _print "$distro" "$version" "$variant"
  fi
}

_print() {
  local distro="$1"
  local version="$2"
  local variant="$3"

  printf -- "%s %s %s\n" "$distro" "$version" "$variant"
}
