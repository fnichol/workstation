#!/usr/bin/env sh
# shellcheck disable=SC2039

_print_usage_docker() {
  local program="$1"
  local version="$2"
  local author="$3"

  echo "${program}-docker $version

    Manages Docker images and containers

    USAGE:
        $program docker [FLAGS] [--] <SUBCOMMAND> [ARG ..]

    FLAGS:
        -h, --help      Prints help information

    SUBCOMMANDS:
        build     Builds a Docker image for distro from a workstation run
        clean     Cleans Docker images for a distro and any related containers
        help      Prints help information
        matrix    Prints a list of distro/version/variant lines
        run       Runs a Docker container from a built image

    SUBCOMMAND HELP:
        $program docker <SUBCOMMAND> --help

    AUTHOR:
        $author
    " | sed 's/^ \{1,4\}//g'
}

cli_docker__invoke() {
  local program version author
  program="$1"
  shift
  version="$1"
  shift
  author="$1"
  shift

  OPTIND=1
  while getopts "h-:" arg; do
    case "$arg" in
      h)
        _print_usage_docker "$program" "$version" "$author"
        return 0
        ;;
      -)
        case "$OPTARG" in
          help)
            _print_usage_docker "$program" "$version" "$author"
            return 0
            ;;
          '')
            # "--" terminates argument processing
            break
            ;;
          *)
            _print_usage_docker "$program" "$version" "$author" >&2
            fail "invalid argument --$OPTARG"
            ;;
        esac
        ;;
      \?)
        _print_usage_docker "$program" "$version" "$author" >&2
        fail "invalid argument; arg=-$OPTARG"
        ;;
    esac
  done
  shift "$((OPTIND - 1))"

  case "${1:-}" in
    build)
      shift

      # shellcheck source=support/lib/cli_docker_build.sh
      . "$ROOT/lib/cli_docker_build.sh"

      cli_docker_build__invoke "$program" "$version" "$author" "$@"
      ;;
    clean)
      shift

      # shellcheck source=support/lib/cli_docker_clean.sh
      . "$ROOT/lib/cli_docker_clean.sh"

      cli_docker_clean__invoke "$program" "$version" "$author" "$@"
      ;;
    matrix)
      shift

      # shellcheck source=support/lib/cli_docker_matrix.sh
      . "$ROOT/lib/cli_docker_matrix.sh"

      cli_docker_matrix__invoke "$program" "$version" "$author" "$@"
      ;;
    run)
      shift

      # shellcheck source=support/lib/cli_docker_run.sh
      . "$ROOT/lib/cli_docker_run.sh"

      cli_docker_run__invoke "$program" "$version" "$author" "$@"
      ;;
    help)
      _print_usage_docker "$program" "$version" "$author"
      return 0
      ;;
    '')
      _print_usage_docker "$program" "$version" "$author" >&2
      fail "missing subcommand argument"
      ;;
    *)
      _print_usage_docker "$program" "$version" "$author" >&2
      fail "invalid argument; arg=${1:-}"
      ;;
  esac
}
