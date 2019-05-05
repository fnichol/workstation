#!/usr/bin/env sh
# shellcheck disable=SC2039

# shellcheck source=support/lib/docker.sh
. "$ROOT/lib/docker.sh"

cmd_docker_run__exec() {
  local img="$1"
  shift
  local opts="${1:-}"
  shift

  if [ -n "$VERBOSE" ]; then
    set -x
  fi

  # shellcheck disable=SC2086
  exec docker run $opts "$img" "$@"
}
