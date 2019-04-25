#!/usr/bin/env sh
# shellcheck disable=SC2039

_print_usage_docker_matrix() {
  local program="$1"
  local version="$2"
  local author="$3"

  local distros
  distros="$(docker__valid_distros | tr '\n' ',' | sed -e 's/,$//' -e 's/,/, /g')"
  local variants
  variants="$(docker__valid_variants | tr '\n' ',' | sed -e 's/,$//' -e 's/,/, /g')"

  echo "${program}-docker-matrix $version

    Prints a list of distro/version/variant lines

    USAGE:
        $program docker matrix [FLAGS] [--] [<DISTRO> [<VERSION> [<VARIANT>]]]

    FLAGS:
        -h, --help      Prints help information

    ARGS:
        <DISTRO>    Name of Linux distribution
                    [values: $distros]
        <VARIANT>   Variant of workstation setup
                    [values: $variants]
        <VERSION>   Release version of a Linux distribution

    AUTHOR:
        $author
    " | sed 's/^ \{1,4\}//g'
}

cli_docker_matrix__invoke() {
  # shellcheck source=support/lib/cmd_docker_matrix.sh
  . "$ROOT/lib/cmd_docker_matrix.sh"

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
        _print_usage_docker_matrix "$program" "$version" "$author"
        return 0
        ;;
      -)
        case "$OPTARG" in
          help)
            _print_usage_docker_matrix "$program" "$version" "$author"
            return 0
            ;;
          '')
            # "--" terminates argument processing
            break
            ;;
          *)
            _print_usage_docker_matrix "$program" "$version" "$author" >&2
            fail "invalid argument --$OPTARG"
            ;;
        esac
        ;;
      \?)
        _print_usage_docker_matrix "$program" "$version" "$author" >&2
        fail "invalid argument; arg=-$OPTARG"
        ;;
    esac
  done
  shift "$((OPTIND - 1))"

  case "${1:-}" in
    help)
      _print_usage_docker_matrix "$program" "$version" "$author"
      return 0
      ;;
    '')
      cmd_docker_matrix__for "_" "_" "_"
      return 0
      ;;
    *)
      if ! docker__valid_distros | grep -q "^$1$"; then
        _print_usage_docker_matrix "$program" "$version" "$author" >&2
        fail "invalid distro value; distro=$1"
      fi

      local distro="$1"
      ;;
  esac
  shift

  case "${1:-}" in
    '')
      cmd_docker_matrix__for "$distro" "_" "_"
      return 0
      ;;
    *)
      if ! docker__valid_versions_for "$distro" | grep -q "^$1$"; then
        _print_usage_docker_matrix "$program" "$version" "$author" >&2
        fail "invalid version value; version=$1"
      fi

      local distro_version="$1"
      ;;
  esac
  shift

  if [ -z "${1:-}" ]; then
    cmd_docker_matrix__for "$distro" "$distro_version" "_"
    return 0
  fi
  local variant="$1"
  shift

  cmd_docker_matrix__for "$distro" "$distro_version" "$variant"
}
