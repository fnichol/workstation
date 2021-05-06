#!/usr/bin/env sh
# shellcheck disable=SC3043

vagrant__vm_variant_name() {
  local distro="$1"
  local version="$2"
  local variant="$3"

  echo "workstation-${distro}-${version}-${variant}"
}

vagrant__valid_distros() {
  echo "_"
  vagrant__distros
}

vagrant__distros() {
  find "$ROOT/distros/vagrant" -type f -exec basename {} \; \
    | sed 's/\.txt$//' \
    | sort
}

vagrant__valid_versions_for() {
  local distro="$1"

  echo "_"
  if [ "_" != "$distro" ]; then
    vagrant__versions_for "$distro"
  fi
}

vagrant__versions_for() {
  local distro="$1"

  awk -F, '{ print $1 }' "$ROOT/distros/vagrant/${distro}.txt"
}

vagrant__valid_variants() {
  echo "_"
  vagrant__variants
}

vagrant__variants() {
  echo "base"
  echo "headless"
  echo "graphical"
}
