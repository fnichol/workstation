#!/usr/bin/env sh
# shellcheck disable=SC2039

_print_usage_docker_run() {
  local program="$1"
  local version="$2"
  local author="$3"

  local distros
  distros="$(docker__valid_distros | tr '\n' ',' | sed -e 's/,$//' -e 's/,/, /g')"
  local variants
  variants="$(docker__valid_variants | tr '\n' ',' | sed -e 's/,$//' -e 's/,/, /g')"

  echo "${program}-docker-run $version

    Runs a Docker container from a built image

    USAGE:
        $program docker run [FLAGS] [OPTIONS] [--] <DISTRO> <VERSION> <VARIANT> [<ARG> ..]

    FLAGS:
        -h, --help      Prints help information
        -v, --verbose   Prints verbose output

    OPTIONS:
        -D, --docker-opts=<OPTS>  Addition options passed to \`docker run\`

    ARGS:
        <ARG>       Additional arguments passed to the container
        <DISTRO>    Name of Linux distribution
                    [values: $distros]
        <VARIANT>   Variant of workstation setup
                    [values: $variants]
        <VERSION>   Release version of a Linux distribution

    AUTHOR:
        $author
    " | sed 's/^ \{1,4\}//g'
}

cli_docker_run__invoke() {
  # shellcheck source=support/lib/cmd_docker_run.sh
  . "$ROOT/lib/cmd_docker_run.sh"

  local program version author
  program="$1"
  shift
  version="$1"
  shift
  author="$1"
  shift

  OPTIND=1
  while getopts "D:hv-:" arg; do
    case "$arg" in
      D)
        local opts="$OPTARG"
        ;;
      h)
        _print_usage_docker_run "$program" "$version" "$author"
        return 0
        ;;
      v)
        VERBOSE=true
        ;;
      -)
        long_optarg="${OPTARG#*=}"
        case "$OPTARG" in
          docker-opts=?*)
            local opts="$long_optarg"
            ;;
          docker-opts*)
            _print_usage_docker_run "$program" "$version" "$author"
            die "missing required argument for --$OPTARG option"
            ;;
          help)
            _print_usage_docker_run "$program" "$version" "$author"
            return 0
            ;;
          verbose)
            VERBOSE=true
            ;;
          '')
            # "--" terminates argument processing
            break
            ;;
          *)
            _print_usage_docker_run "$program" "$version" "$author" >&2
            die "invalid argument --$OPTARG"
            ;;
        esac
        ;;
      \?)
        _print_usage_docker_run "$program" "$version" "$author" >&2
        die "invalid argument; arg=-$OPTARG"
        ;;
    esac
  done
  shift "$((OPTIND - 1))"

  case "${1:-}" in
    help)
      _print_usage_docker_run "$program" "$version" "$author"
      return 0
      ;;
    '')
      _print_usage_docker_run "$program" "$version" "$author" >&2
      die "missing distro argument"
      ;;
    *)
      if ! docker__valid_distros | grep -q "^$1$"; then
        _print_usage_docker_run "$program" "$version" "$author" >&2
        die "invalid distro value; distro=$1"
      fi

      local distro="$1"
      ;;
  esac
  shift

  case "${1:-}" in
    '')
      _print_usage_docker_run "$program" "$version" "$author" >&2
      die "missing version argument"
      ;;
    *)
      if ! docker__valid_versions_for "$distro" | grep -q "^$1$"; then
        _print_usage_docker_run "$program" "$version" "$author" >&2
        die "invalid version value; version=$1"
      fi

      local distro_version="$1"
      ;;
  esac
  shift

  if [ -z "${1:-}" ]; then
    _print_usage_docker_run "$program" "$version" "$author" >&2
    die "missing variant argument"
  fi
  local variant="$1"
  shift

  local img
  img="$(docker__img_variant_name "$distro" "$distro_version" "$variant")"

  cmd_docker_run__exec "$img" "${opts:-}" "$@"
}
