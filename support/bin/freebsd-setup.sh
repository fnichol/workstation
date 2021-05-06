#!/usr/bin/env sh
# shellcheck disable=SC3043

print_usage() {
  local program="$1"
  local version="$2"
  local author="$3"

  echo "$program $version

    Sets up the initial FreeBSD environment with a non-root user

    USAGE:
        $program [FLAGS] [OPTIONS] [--]

    FLAGS:
        -h, --help      Prints help information
        -V, --version   Prints version information
        -v, --verbose   Prints verbose output

    OPTIONS:
        -u, --user=<OPTS>     Non-root user to be created and used
                              [default: jdoe]
        -g, --group=<OPTS>    Non-root group to be created and used
                              [default: jdoe]

    AUTHOR:
        $author
    " | sed 's/^ \{1,4\}//g'
}

main() {
  set -eu
  if [ -n "${DEBUG:-}" ]; then set -v; fi
  if [ -n "${TRACE:-}" ]; then set -xv; fi

  local program version author
  program="$(basename "$0")"
  version="0.1.0"
  author="Fletcher Nichol <fnichol@nichol.ca>"

  cli_invoke "$program" "$version" "$author" "$@"
}

cli_invoke() {
  local program version author user group
  program="$1"
  shift
  version="$1"
  shift
  author="$1"
  shift

  VERBOSE=""
  user="jdoe"
  group="$user"

  OPTIND=1
  while getopts "hg:u:vV-:" arg; do
    case "$arg" in
      h)
        print_usage "$program" "$version" "$author"
        return 0
        ;;
      g)
        group="$OPTARG"
        ;;
      u)
        user="$OPTARG"
        ;;
      v)
        VERBOSE=true
        ;;
      V)
        print_version "$program" "$version" "${VERBOSE:-}"
        return 0
        ;;
      -)
        long_optarg="${OPTARG#*=}"
        case "$OPTARG" in
          help)
            print_usage "$program" "$version" "$author"
            return 0
            ;;
          group=?*)
            group="$long_optarg"
            ;;
          group*)
            print_usage "$program" "$version" "$author"
            fail "missing required argument for --$OPTARG option"
            ;;
          user=?*)
            user="$long_optarg"
            ;;
          user*)
            print_usage "$program" "$version" "$author"
            fail "missing required argument for --$OPTARG option"
            ;;
          verbose)
            VERBOSE=true
            ;;
          version)
            print_version "$program" "$version" "${VERBOSE:-}"
            return 0
            ;;
          '')
            # "--" terminates argument processing
            break
            ;;
          *)
            print_usage "$program" "$version" "$author" >&2
            fail "invalid argument --$OPTARG"
            ;;
        esac
        ;;
      \?)
        print_usage "$program" "$version" "$author" >&2
        fail "invalid argument; arg=-$OPTARG"
        ;;
    esac
  done
  shift "$((OPTIND - 1))"

  setup "$user" "$group"
}

setup() {
  local user="$1"
  shift
  local group="$1"
  shift

  pkg install --yes sudo

  pw groupadd -n "$group"
  pw useradd -n "$user" -c "$user" -g "$group" -m -s "/bin/sh"
  pw usermod -n "$user" -G wheel

  sed -i.bak 's/^# \(%wheel .*NOPASSWD.*\)$/\1/' /usr/local/etc/sudoers
  rm -f /usr/local/etc/sudoers.bak
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

fail() {
  echo "" >&2
  echo "xxx $1" >&2
  echo "" >&2
  return 1
}

main "$@"
