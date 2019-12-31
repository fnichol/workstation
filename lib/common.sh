#!/usr/bin/env sh
# shellcheck disable=SC2039

cleanup_file() {
  local file="$1"

  # If a tempfile hasn't been setup yet, create it
  if [ -z "${__cleanup_files:-}" ]; then
    __cleanup_files="$(mktemp_file)"

    # If the result string is empty, tempfile wasn't created so report failure
    if [ -z "$__cleanup_files" ]; then
      return 1
    fi
  fi

  echo "$file" >>"$__cleanup_files"
}

download() {
  local url="$1"
  local dst="$2"
  local code

  # Attempt to download with wget, if found. If successful, quick return
  if command -v wget >/dev/null; then
    info "Downlading via wget: ${url}"
    wget -q -O "${dst}" "${url}"
    code="$?"
    if [ $code -eq 0 ]; then
      return 0
    else
      local e="wget failed to download file, perhaps wget doesn't have"
      e="$e SSL support and/or no CA certificates are present?"
      warn "$e"
    fi
  fi

  # Attempt to download with curl, if found. If successful, quick return
  if command -v curl >/dev/null; then
    info "Downlading via curl: ${url}"
    curl -sSfL "${url}" -o "${dst}"
    code="$?"
    if [ $code -eq 0 ]; then
      return 0
    else
      local e="curl failed to download file, perhaps curl doesn't have"
      e="$e SSL support and/or no CA certificates are present?"
      warn "$e"
    fi
  fi

  # If we reach this point, wget and curl have failed and we're out of options
  exit_with "Required: SSL-enabled 'curl' or 'wget' on PATH with" 6
}

ensure_not_root() {
  need_cmd id

  if [ "$(id -u)" -eq 0 ]; then
    # shellcheck disable=SC2154
    warn "$_program must be run as a non-root user, please re-run to try again."
    exit_with "Program run with root permissions" 1
  fi
}

exit_with() {
  local msg="$1"

  case "${TERM:-}" in
    *term | xterm-* | rxvt | screen | screen-*)
      printf -- "\n\033[1;31;40mERROR: \033[1;37;40m%s\033[0m\n\n" "$msg" >&2
      ;;
    *)
      printf -- "\nERROR: %s\n\n" "$msg" >&2
      ;;
  esac

  exit "${2:-99}"
}

fail() {
  local msg="$1"

  case "${TERM:-}" in
    *term | xterm-* | rxvt | screen | screen-*)
      printf -- "\n\033[1;31;40mxxx \033[1;37;40m%s\033[0m\n\n" "$msg" >&2
      ;;
    *)
      printf -- "\nxxx %s\n\n" "$msg" >&2
      ;;
  esac

  return 1
}

get_sudo() {
  local hostname="$1"

  need_cmd sudo

  sudo -p "[sudo required for some tasks] Password for %u@$hostname: " echo
}

header() {
  local msg="$1"

  case "${TERM:-}" in
    *term | xterm-* | rxvt | screen | screen-*)
      printf -- "\033[1;36;40m--- \033[1;37;40m%s\033[0m\n" "$msg"
      ;;
    *)
      printf -- "--- %s\n" "$msg"
      ;;
  esac
}

# Indent the output from a command while preserving the command's exit code.
#
# In minimal/POSIX shells there is no support for `set -o pipefail` which means
# that the exit code of the first command in a shell pipeline won't be
# addressable in an easy way. This implementation uses a temp file to ferry the
# original command's exit code from a subshell back into the main function. The
# output can be aligned with a pipe to `sed` as before but now we have an
# implementation which mimicks a `set -o pipefail` which should work on all
# Bourne shells. Note that the `set -o errexit` is disabled during the
# command's invocation so that its exit code can be captured.
#
# Based on implementation from: https://stackoverflow.com/a/54931544
indent() {
  need_cmd cat
  need_cmd sed

  local ecfile ec
  ecfile="$(mktemp_file)"
  cleanup_file "$ecfile"

  set +e
  {
    "$@" 2>&1
    echo "$?" >"$ecfile"
  } | sed 's/^/       /'
  ec="$(cat "$ecfile")"
  set -e

  return "${ec:-5}"
}

info() {
  local msg="$1"

  case "${TERM:-}" in
    *term | xterm-* | rxvt | screen | screen-*)
      printf -- "\033[1;36;40m  - \033[1;37;40m%s\033[0m\n" "$msg"
      ;;
    *)
      printf -- "  - %s\n" "$msg"
      ;;
  esac
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

# Most systems use the first no-argument version, however Mac OS X 10.10
# (Yosemite) and older don't allow the no-argument version, hence the second
# fallback version.
mktemp_file() {
  mktemp 2>/dev/null || mktemp -t tmp
}

need_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    exit_with "Required command '$1' not found on PATH" 127
  fi
}

# Inspired by Cargo's version implementation, see: https://git.io/fjsOh
print_version() {
  local program="$1"
  local version="$2"
  local verbose="$3"

  if command -v git >/dev/null; then
    local date sha
    date="$(git show -s --format=%cd --date=short)"
    sha="$(git show -s --format=%h)"
    if ! git diff-index --quiet HEAD --; then
      sha="${sha}-dirty"
    fi

    echo "$program $version ($sha $date)"

    if [ -n "$verbose" ]; then
      local long_sha
      long_sha="$(git show -s --format=%H)"
      case "$sha" in
        *-dirty) long_sha="${long_sha}-dirty" ;;
      esac

      echo "release: $version"
      echo "commit-hash: $long_sha"
      echo "commit-date: $date"
    fi
  else
    echo "$program $version"

    if [ -n "$verbose" ]; then
      echo "release: $version"
    fi
  fi
}

trap_cleanup() {
  set +e

  if [ -n "${__cleanup_files:-}" ] && [ -f "$__cleanup_files" ]; then
    while read -r file; do
      rm -f "$file"
    done <"$__cleanup_files"
    rm -f "$__cleanup_files"
  fi
}

warn() {
  local msg="$1"

  case "${TERM:-}" in
    *term | xterm-* | rxvt | screen | screen-*)
      printf -- "\033[1;31;40m!!! \033[1;37;40m%s\033[0m\n" "$msg" >&2
      ;;
    *)
      printf -- "!!! %s\n" "$msg" >&2
      ;;
  esac
}
