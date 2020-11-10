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

  need_cmd uname

  case "$(uname -s)" in
    OpenBSD)
      need_cmd doas

      doas true
      ;;
    *)
      need_cmd sudo

      sudo -p "[sudo required for some tasks] Password for %u@$hostname: " true
      ;;
  esac
}

# Keep-alive: update existing sudo time stamp if set, otherwise do nothing.
# See: https://gist.github.com/cowboy/3118588
keep_sudo() {
  local cmd

  need_cmd uname

  case "$(uname -s)" in
    OpenBSD)
      need_cmd doas
      cmd="doas"
      ;;
    *)
      need_cmd sudo
      cmd="sudo"
      ;;
  esac

  while true; do
    "$cmd" -n true
    sleep 60
    kill -0 "$$" || exit
  done 2>/dev/null &
}

sorted_git_tags() {
  local repo="$1"

  need_cmd awk
  need_cmd git

  # The `--sort` option on `git ls-remote` was introduced in Git 2.18.0, so
  # if it's older then we'll have to use GNU/sort's `--version-sort` to help.
  # Oi
  local version
  version="$(git --version | awk '{ print $NF }')"
  if version_ge "$version" 2 18; then
    git ls-remote --tags --sort=version:refname "$repo"
  else
    need_cmd sort

    git ls-remote --tags "$repo" \
      | sort --field-separator='/' --key=3 --version-sort
  fi
}

version_ge() {
  local version="$1"
  local maj="$2"
  local min="$3"

  [ "$(echo "$version" | awk -F'.' '{ print $1 }')" -ge "$maj" ] \
    && [ "$(echo "$version" | awk -F'.' '{ print $2 }')" -ge "$min" ]
}
