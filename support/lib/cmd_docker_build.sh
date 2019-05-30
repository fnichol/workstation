#!/usr/bin/env sh
# shellcheck shell=sh disable=SC2039

# shellcheck source=support/lib/docker.sh
. "$ROOT/lib/docker.sh"

cmd_docker_build__for() {
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
    for variant in $(docker__variants); do
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

  if [ "pre" = "$variant" ]; then
    _build_pre "$distro" "$version" "$force"
  else
    _build_variant "$distro" "$version" "$variant" "$force"
  fi
}

_build_pre() {
  local distro="$1"
  local version="$2"
  local force="$3"

  local img
  img_pre="$(docker__img_pre_name "$distro" "$version")"

  if [ -z "$force" ] && docker__img_pre_exists "$distro" "$version"; then
    echo "--- Pre image exists, skipping; img_pre=$img_pre"
    return 0
  fi

  local dockerfile="$ROOT/dockerfiles/Dockerfile.$distro"
  if [ ! -f "$dockerfile" ]; then
    echo >&2
    echo "xxx dockerfile not found; dockerfile=$dockerfile" >&2
    echo >&2
    return 1
  fi

  echo "--- Building pre image; img_pre=$img_pre"
  docker image build \
    --pull \
    --force-rm \
    --build-arg "VERSION=$version" \
    --tag "$img_pre" \
    - \
    <"$dockerfile"
}

_build_variant() {
  local distro="$1"
  local version="$2"
  local variant="$3"
  local force="$4"

  if ! docker__img_pre_exists "$distro" "$version"; then
    _build_pre "$distro" "$version" "$force"
  fi

  local img_pre img
  img_pre="$(docker__img_pre_name "$distro" "$version")"
  img="$(docker__img_variant_name "$distro" "$version" "$variant")"

  if [ -z "$force" ] && docker__img_variant_exists "$distro" "$version" "$variant"; then
    echo "--- Image exists, skipping; img=$img"
    return 0
  fi

  echo "--- Running workstation; variant=$variant, img_pre=$img_pre"
  cid="$(docker container run \
    --detach \
    --volume="$(pwd)":/usr/src:ro \
    "$img_pre" \
    /usr/src/bin/prep "--profile=$variant")"
  docker container attach "$cid"

  echo "--- Building image; img=$img"
  docker container commit --change='CMD ["/bin/bash", "-l"]' "$cid" "$img"
  docker container rm "$cid"
}
