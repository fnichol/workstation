#!/usr/bin/env sh
# shellcheck disable=SC3043

_print_usage_vagrant() {
  local program="$1"
  local version="$2"
  local author="$3"

  echo "${program}-vagrant $version

    Manages Vagrant virtual machines

    USAGE:
        $program vagrant [FLAGS] [--] <SUBCOMMAND> [ARG ..]

    FLAGS:
        -h, --help      Prints help information

    SUBCOMMANDS:
        build     Builds Vagrant virtual machines for a distro
        console   Launches a console session in the built virtual machine
        clean     Cleans and destroys Vagrant virtual machines
        help      Prints help information
        matrix    Prints a list of distro/version/variant lines

    SUBCOMMAND HELP:
        $program vagrant <SUBCOMMAND> --help

    AUTHOR:
        $author
    " | sed 's/^ \{1,4\}//g'
}

cli_vagrant__invoke() {
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
        _print_usage_vagrant "$program" "$version" "$author"
        return 0
        ;;
      -)
        case "$OPTARG" in
          help)
            _print_usage_vagrant "$program" "$version" "$author"
            return 0
            ;;
          '')
            # "--" terminates argument processing
            break
            ;;
          *)
            _print_usage_vagrant "$program" "$version" "$author" >&2
            die "invalid argument --$OPTARG"
            ;;
        esac
        ;;
      \?)
        _print_usage_vagrant "$program" "$version" "$author" >&2
        die "invalid argument; arg=-$OPTARG"
        ;;
    esac
  done
  shift "$((OPTIND - 1))"

  case "${1:-}" in
    build)
      shift

      # shellcheck source=support/lib/cli_vagrant_build.sh
      . "$ROOT/lib/cli_vagrant_build.sh"

      cli_vagrant_build__invoke "$program" "$version" "$author" "$@"
      ;;
    clean)
      shift

      # shellcheck source=support/lib/cli_vagrant_clean.sh
      . "$ROOT/lib/cli_vagrant_clean.sh"

      cli_vagrant_clean__invoke "$program" "$version" "$author" "$@"
      ;;
    console)
      shift

      # shellcheck source=support/lib/cli_vagrant_console.sh
      . "$ROOT/lib/cli_vagrant_console.sh"

      cli_vagrant_console__invoke "$program" "$version" "$author" "$@"
      ;;
    matrix)
      shift

      # shellcheck source=support/lib/cli_vagrant_matrix.sh
      . "$ROOT/lib/cli_vagrant_matrix.sh"

      cli_vagrant_matrix__invoke "$program" "$version" "$author" "$@"
      ;;
    help)
      _print_usage_vagrant "$program" "$version" "$author"
      return 0
      ;;
    '')
      _print_usage_vagrant "$program" "$version" "$author" >&2
      die "missing subcommand argument"
      ;;
    *)
      _print_usage_vagrant "$program" "$version" "$author" >&2
      die "invalid argument; arg=${1:-}"
      ;;
  esac
}
