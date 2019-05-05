#!/usr/bin/env sh
# shellcheck disable=SC2039

_print_usage_docker_clean() {
  local program="$1"
  local version="$2"
  local author="$3"

  local distros
  distros="$(docker__valid_distros | tr '\n' ',' | sed -e 's/,$//' -e 's/,/, /g')"
  local variants
  variants="$(docker__valid_variants | tr '\n' ',' | sed -e 's/,$//' -e 's/,/, /g')"

  echo "${program}-docker-clean $version

    Cleans Docker images for a distro and any related containers

    USAGE:
        $program docker clean [FLAGS] [--] [<DISTRO> [<VERSION> [<VARIANT>]]]

    FLAGS:
        -h, --help      Prints help information
        -y, --yes       Answer yes for all questions

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

cli_docker_clean__invoke() {
  # shellcheck source=support/lib/cmd_docker_clean.sh
  . "$ROOT/lib/cmd_docker_clean.sh"

  local program version author answer_yes
  program="$1"
  shift
  version="$1"
  shift
  author="$1"
  shift
  answer_yes=""

  OPTIND=1
  while getopts "hy-:" arg; do
    case "$arg" in
      h)
        _print_usage_docker_clean "$program" "$version" "$author"
        return 0
        ;;
      y)
        answer_yes=true
        ;;
      -)
        case "$OPTARG" in
          help)
            _print_usage_docker_clean "$program" "$version" "$author"
            return 0
            ;;
          yes)
            answer_yes=true
            ;;
          '')
            # "--" terminates argument processing
            break
            ;;
          *)
            _print_usage_docker_clean "$program" "$version" "$author" >&2
            fail "invalid argument --$OPTARG"
            ;;
        esac
        ;;
      \?)
        _print_usage_docker_clean "$program" "$version" "$author" >&2
        fail "invalid argument; arg=-$OPTARG"
        ;;
    esac
  done
  shift "$((OPTIND - 1))"

  case "${1:-}" in
    help)
      _print_usage_docker_clean "$program" "$version" "$author"
      return 0
      ;;
    '')
      cmd_docker_clean__for "_" "_" "_" "$answer_yes"
      return 0
      ;;
    *)
      if ! docker__valid_distros | grep -q "^$1$"; then
        _print_usage_docker_clean "$program" "$version" "$author" >&2
        fail "invalid distro value; distro=$1"
      fi

      local distro="$1"
      ;;
  esac
  shift

  case "${1:-}" in
    '')
      cmd_docker_clean__for "$distro" "_" "_" "$answer_yes"
      return 0
      ;;
    *)
      if ! docker__valid_versions_for "$distro" | grep -q "^$1$"; then
        _print_usage_docker_clean "$program" "$version" "$author" >&2
        fail "invalid version value; version=$1"
      fi

      local distro_version="$1"
      ;;
  esac
  shift

  if [ -z "${1:-}" ]; then
    cmd_docker_clean__for "$distro" "$distro_version" "_" "$answer_yes"
    return 0
  fi
  local variant="$1"
  shift

  cmd_docker_clean__for "$distro" "$distro_version" "$variant" "$answer_yes"
}
