#!/usr/bin/env sh
# shellcheck disable=SC2039

# https://stackoverflow.com/a/28466267

_print_usage_main() {
  local program="$1"
  local version="$2"
  local author="$3"

  echo "$program $version

    Continuous integration automation tooling

    USAGE:
        $program [FLAGS] [--] <SUBCOMMAND> [ARG ..]

    FLAGS:
        -h, --help      Prints help information
        -V, --version   Prints version information
        -v, --verbose   Prints verbose output

    SUBCOMMANDS:
        docker    Manages Docker images and containers
        help      Prints help information
        version   Prints version information

    SUBCOMMAND HELP:
        $program <SUBCOMMAND> --help

    AUTHOR:
        $author
    " | sed 's/^ \{1,4\}//g'
}

cli__invoke_main() {
  local program version author
  program="$1"
  shift
  version="$1"
  shift
  author="$1"
  shift

  OPTIND=1
  while getopts "hvV-:" arg; do
    case "$arg" in
      h)
        _print_usage_main "$program" "$version" "$author"
        return 0
        ;;
      v)
        VERBOSE=true
        ;;
      V)
        _print_version "$program" "$version" "${VERBOSE:-}"
        return 0
        ;;
      -)
        case "$OPTARG" in
          help)
            _print_usage_main "$program" "$version" "$author"
            return 0
            ;;
          verbose)
            VERBOSE=true
            ;;
          version)
            _print_version "$program" "$version" "${VERBOSE:-}"
            return 0
            ;;
          '')
            # "--" terminates argument processing
            break
            ;;
          *)
            _print_usage_main "$program" "$version" "$author" >&2
            die "invalid argument --$OPTARG"
            ;;
        esac
        ;;
      \?)
        _print_usage_main "$program" "$version" "$author" >&2
        die "invalid argument; arg=-$OPTARG"
        ;;
    esac
  done
  shift "$((OPTIND - 1))"

  if [ -z "${VERBOSE:-}" ]; then
    VERBOSE=""
  fi

  case "${1:-}" in
    docker)
      shift

      # shellcheck source=support/lib/cli_docker.sh
      . "$ROOT/lib/cli_docker.sh"

      cli_docker__invoke "$program" "$version" "$author" "$@"
      ;;
    help)
      _print_usage_main "$program" "$version" "$author"
      return 0
      ;;
    version)
      _print_version "$program" "$version" "$VERBOSE"
      return 0
      ;;
    '')
      _print_usage_main "$program" "$version" "$author" >&2
      die "missing subcommand argument"
      ;;
    *)
      _print_usage_main "$program" "$version" "$author" >&2
      die "invalid argument; arg=${1:-}"
      ;;
  esac
}

# Inspired by Cargo's version implementation, see: https://git.io/fjsOh
_print_version() {
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
