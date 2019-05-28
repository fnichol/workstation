#!/usr/bin/env sh
# shellcheck shell=sh disable=SC2039

# shellcheck source=support/lib/docker.sh
. "$ROOT/lib/docker.sh"

cmd_docker_clean__for() {
  local distro="$1"
  local version="$2"
  local variant="$3"
  local force="$4"

  if [ "_" = "$distro" ]; then
    for distro in $(docker__distros); do
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
    for version in $(docker__versions_for "$distro"); do
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
    # Reverse list of variants so that all derivatives are removed before the
    # "pre" image
    for variant in $(docker__variants | _reverse_lines); do
      _clean "$distro" "$version" "$variant" "$force"
    done
  else
    _clean "$distro" "$version" "$variant" "$force"
  fi
}

_clean() {
  local distro="$1"
  local version="$2"
  local variant="$3"
  local force="$4"

  local img
  img="$(docker__img_variant_name "$distro" "$version" "$variant")"
  local containers images

  if [ -z "$force" ]; then
    _confirm "Are you sure you want to clean $img?"
  fi

  # Kill any currently running containers that are descendant from `$img`
  containers="$(docker container ls --all --quiet \
    --filter "ancestor=$img" --filter status=running)"
  if [ -n "$containers" ]; then
    echo "--- Killing running containers; img=$img"
    echo "$containers" | xargs docker container kill
  fi

  # Remove all containers that are descendant from `$img`
  containers="$(docker container ls --all --quiet --filter "ancestor=$img")"
  if [ -n "$containers" ]; then
    echo "--- Removing containers; img=$img"
    echo "$containers" | xargs docker container rm
  fi

  # Remove all images related to `$img
  images="$(docker image ls --quiet "$img")"
  if [ -n "$images" ]; then
    echo "--- Removing images; img=$img"
    echo "$images" | xargs docker image rm
  fi
}

_confirm() {
  local msg="$1"
  local answer

  while true; do
    printf -- "%s [%s/%s/%s] " "$msg" "Yes" "no" "quit"
    read -r answer

    case "$answer" in
      q | quit | Q | Quit | QUIT)
        echo "Quitting"
        exit 0
        ;;
      y | Y | yes | Yes | YES | '')
        break
        ;;
    esac
  done
}

# Reverse order of lines (emulating `tac`)
# Thanks to "Handy One-Liners for Awk": http://tiny.cc/daxe6y
_reverse_lines() {
  awk '{a[i++]=$0} END {for (j=i-1; j>=0;) print a[j--] }'
}
