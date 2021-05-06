#!/usr/bin/env sh
# shellcheck disable=SC3043

# shellcheck source=support/lib/vagrant.sh
. "$ROOT/lib/vagrant.sh"

cmd_vagrant_console__exec() {
  local vm="$1"
  shift

  if [ -n "$VERBOSE" ]; then
    set -x
  fi

  exec vagrant ssh "$vm"
}
