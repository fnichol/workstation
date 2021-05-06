#!/usr/bin/env sh
# shellcheck disable=SC3043

_print_usage_vagrant_console() {
  local program="$1"
  local version="$2"
  local author="$3"

  local distros
  distros="$(vagrant__valid_distros | tr '\n' ',' | sed -e 's/,$//' -e 's/,/, /g')"
  local variants
  variants="$(vagrant__valid_variants | tr '\n' ',' | sed -e 's/,$//' -e 's/,/, /g')"

  echo "${program}-vagrant-console $version

    Launches a console session in the built virtual machine

    USAGE:
        $program vagrant console [FLAGS] [OPTIONS] [--] <DISTRO> <VERSION> <VARIANT> [<ARG> ..]

    FLAGS:
        -h, --help      Prints help information
        -v, --verbose   Prints verbose output

    ARGS:
        <ARG>       Additional arguments passed to the virtual machine
        <DISTRO>    Name of Linux distribution
                    [values: $distros]
        <VARIANT>   Variant of workstation setup
                    [values: $variants]
        <VERSION>   Release version of a Linux distribution

    AUTHOR:
        $author
    " | sed 's/^ \{1,4\}//g'
}

cli_vagrant_console__invoke() {
  # shellcheck source=support/lib/cmd_vagrant_console.sh
  . "$ROOT/lib/cmd_vagrant_console.sh"

  local program version author
  program="$1"
  shift
  version="$1"
  shift
  author="$1"
  shift

  OPTIND=1
  while getopts "hv-:" arg; do
    case "$arg" in
      h)
        _print_usage_vagrant_console "$program" "$version" "$author"
        return 0
        ;;
      v)
        VERBOSE=true
        ;;
      -)
        case "$OPTARG" in
          help)
            _print_usage_vagrant_console "$program" "$version" "$author"
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
            _print_usage_vagrant_console "$program" "$version" "$author" >&2
            die "invalid argument --$OPTARG"
            ;;
        esac
        ;;
      \?)
        _print_usage_vagrant_console "$program" "$version" "$author" >&2
        die "invalid argument; arg=-$OPTARG"
        ;;
    esac
  done
  shift "$((OPTIND - 1))"

  case "${1:-}" in
    help)
      _print_usage_vagrant_console "$program" "$version" "$author"
      return 0
      ;;
    '')
      _print_usage_vagrant_console "$program" "$version" "$author" >&2
      die "missing distro argument"
      ;;
    *)
      if ! vagrant__valid_distros | grep -q "^$1$"; then
        _print_usage_vagrant_console "$program" "$version" "$author" >&2
        die "invalid distro value; distro=$1"
      fi

      local distro="$1"
      ;;
  esac
  shift

  case "${1:-}" in
    '')
      _print_usage_vagrant_console "$program" "$version" "$author" >&2
      die "missing version argument"
      ;;
    *)
      if ! vagrant__valid_versions_for "$distro" | grep -q "^$1$"; then
        _print_usage_vagrant_console "$program" "$version" "$author" >&2
        die "invalid version value; version=$1"
      fi

      local distro_version="$1"
      ;;
  esac
  shift

  if [ -z "${1:-}" ]; then
    _print_usage_vagrant_console "$program" "$version" "$author" >&2
    die "missing variant argument"
  fi
  local variant="$1"
  shift

  local vm
  vm="$(vagrant__vm_variant_name "$distro" "$distro_version" "$variant")"

  cmd_vagrant_console__exec "$vm" "${opts:-}" "$@"
}
