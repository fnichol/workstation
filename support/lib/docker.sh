#!/usr/bin/env sh
# shellcheck shell=sh disable=SC2039

docker__img_pre_name() {
  docker__img_variant_name "$1" "$2" "pre"
}

docker__img_variant_name() {
  local distro="$1"
  local version="$2"
  local variant="$3"

  echo "fnichol/workstation-${distro}-${version}-${variant}"
}

docker__img_pre_exists() {
  local distro="$1"
  local version="$2"
  local img_pre images

  img_pre="$(docker__img_pre_name "$distro" "$version")"

  images="$(docker image ls --quiet "$img_pre")"
  if [ -z "$images" ]; then
    return 1
  fi
}

docker__img_variant_exists() {
  local distro="$1"
  local version="$2"
  local variant="$3"
  local img images

  img="$(docker__img_variant_name "$distro" "$version" "$variant")"

  images="$(docker image ls --quiet "$img")"
  if [ -z "$images" ]; then
    return 1
  fi
}

docker__valid_distros() {
  echo "_"
  docker__distros
}

docker__distros() {
  find "$ROOT/dockerfiles" -type f -name 'Dockerfile.*' -exec basename {} \; \
    | sed 's/^Dockerfile\.//' \
    | sort
}

docker__valid_versions_for() {
  local distro="$1"

  echo "_"
  if [ "_" != "$distro" ]; then
    docker__versions_for "$distro"
  fi
}

docker__versions_for() {
  local distro="$1"

  cat "$ROOT/distros/${distro}.txt"
}

docker__valid_variants() {
  echo "_"
  docker__variants
}

docker__variants() {
  echo "pre"
  echo "base"
  echo "headless"
  echo "graphical"
}
