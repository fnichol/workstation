#!/usr/bin/env sh
# shellcheck disable=SC2039

_print_usage_vagrant_build() {
  local program="$1"
  local version="$2"
  local author="$3"

  local distros
  distros="$(vagrant__valid_distros | tr '\n' ',' | sed -e 's/,$//' -e 's/,/, /g')"
  local variants
  variants="$(vagrant__valid_variants | tr '\n' ',' | sed -e 's/,$//' -e 's/,/, /g')"

  echo "${program}-vagrant-build $version

    Builds Vagrant virtual machines for a distro

    USAGE:
        $program docker build [FLAGS] [--] [<DISTRO> [<VERSION> [<VARIANT>]]]

    FLAGS:
        -F, --force     Builds whether or not a previous image exists
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

cli_vagrant_build__invoke() {
  # shellcheck source=support/lib/cmd_vagrant_build.sh
  . "$ROOT/lib/cmd_vagrant_build.sh"

  local program version author force
  program="$1"
  shift
  version="$1"
  shift
  author="$1"
  shift
  force=""

  OPTIND=1
  while getopts "Fh-:" arg; do
    case "$arg" in
      F)
        force=true
        ;;
      h)
        _print_usage_vagrant_build "$program" "$version" "$author"
        return 0
        ;;
      -)
        case "$OPTARG" in
          force)
            force=true
            ;;
          help)
            _print_usage_vagrant_build "$program" "$version" "$author"
            return 0
            ;;
          '')
            # "--" terminates argument processing
            break
            ;;
          *)
            _print_usage_vagrant_build "$program" "$version" "$author" >&2
            die "invalid argument --$OPTARG"
            ;;
        esac
        ;;
      \?)
        _print_usage_vagrant_build "$program" "$version" "$author" >&2
        die "invalid argument; arg=-$OPTARG"
        ;;
    esac
  done
  shift "$((OPTIND - 1))"

  case "${1:-}" in
    help)
      _print_usage_vagrant_build "$program" "$version" "$author"
      return 0
      ;;
    '')
      cmd_vagrant_build__for "_" "_" "_" "$force"
      return 0
      ;;
    *)
      if ! vagrant__valid_distros | grep -q "^$1$"; then
        _print_usage_vagrant_build "$program" "$version" "$author" >&2
        die "invalid distro value; distro=$1"
      fi

      local distro="$1"
      ;;
  esac
  shift

  case "${1:-}" in
    '')
      cmd_vagrant_build__for "$distro" "_" "_" "$force"
      return 0
      ;;
    *)
      if ! vagrant__valid_versions_for "$distro" | grep -q "^$1$"; then
        _print_usage_vagrant_build "$program" "$version" "$author" >&2
        die "invalid version value; version=$1"
      fi

      local distro_version="$1"
      ;;
  esac
  shift

  if [ -z "${1:-}" ]; then
    cmd_vagrant_build__for "$distro" "$distro_version" "_" "$force"
    return 0
  fi
  local variant="$1"
  shift

  cmd_vagrant_build__for "$distro" "$distro_version" "$variant" "$force"
}
