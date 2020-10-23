#!/usr/bin/env sh
# shellcheck shell=sh disable=SC2039

# shellcheck source=support/lib/vagrant.sh
. "$ROOT/lib/vagrant.sh"

cmd_vagrant_build__for() {
  local distro="$1"
  local version="$2"
  local variant="$3"
  local force="$4"

  if [ "_" = "$distro" ]; then
    for distro in $(vagrant__distros); do
      _process_distro "$distro" "$version" "$variant" "$force"
    done
  else
    _process_distro "$distro" "$version" "$variant" "$force"
  fi
}

_process_distro() {
  local distro="$1"
  local version="$2"
  local variant="$3"
  local force="$4"

  if [ "_" = "$version" ]; then
    for version in $(vagrant__versions_for "$distro"); do
      _process_version "$distro" "$version" "$variant" "$force"
    done
  else
    _process_version "$distro" "$version" "$variant" "$force"
  fi
}

_process_version() {
  local distro="$1"
  local version="$2"
  local variant="$3"
  local force="$4"

  if [ "_" = "$variant" ]; then
    for variant in $(vagrant__variants); do
      _build "$distro" "$version" "$variant" "$force"
    done
  else
    _build "$distro" "$version" "$variant" "$force"
  fi
}

_build() {
  local distro="$1"
  local version="$2"
  local variant="$3"
  local force="$4"

  local vm
  vm="$(vagrant__vm_variant_name "$distro" "$version" "$variant")"

  section "Building vm; vm=$vm"
  vagrant up "$vm"
}
