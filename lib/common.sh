#!/usr/bin/env sh
# shellcheck disable=SC2039

ensure_not_root() {
  local program="$1"

  need_cmd id

  if [ "$(id -u)" -eq 0 ]; then
    # shellcheck disable=SC2154
    warn "$program must be run as a non-root user, please re-run to try again."
    die "Program run with root permissions"
  fi
}

get_sudo() {
  local hostname="$1"

  need_cmd sudo

  sudo -p "[sudo required for some tasks] Password for %u@$hostname: " echo
}

# Keep-alive: update existing sudo time stamp if set, otherwise do nothing.
# See: https://gist.github.com/cowboy/3118588
keep_sudo() {
  need_cmd sudo

  while true; do
    sudo -n true
    sleep 60
    kill -0 "$$" || exit
  done 2>/dev/null &
}
