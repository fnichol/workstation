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
        print_version "$program" "$version"
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
            print_version "$program" "$version" "true"
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
      print_version "$program" "$version" "true"
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
