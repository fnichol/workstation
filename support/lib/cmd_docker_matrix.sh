#!/usr/bin/env sh
# shellcheck disable=SC2039

# shellcheck source=support/lib/docker.sh
. "$ROOT/lib/docker.sh"

cmd_docker_matrix__for() {
  local distro="$1"
  local version="$2"
  local variant="$3"

  if [ "_" = "$distro" ]; then
    for distro in $(docker__distros); do
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
    for version in $(docker__versions_for "$distro"); do
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
    for variant in $(docker__variants); do
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
