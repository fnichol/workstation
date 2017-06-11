download() {
  local url="$1"
  local dst="$2"
  local code

  # Attempt to download with wget, if found. If successful, quick return
  if command -v wget > /dev/null; then
    info "Downlading via wget: ${url}"
    wget -q -O "${dst}" "${url}"
    code="$?"
    if [ $code -eq 0 ]; then
      return 0
    else
      local e="wget failed to download file, perhaps wget doesn't have"
      e="$e SSL support and/or no CA certificates are present?"
      warn "$e"
    fi
  fi

  # Attempt to download with curl, if found. If successful, quick return
  if command -v curl > /dev/null; then
    info "Downlading via curl: ${url}"
    curl -sSfL "${url}" -o "${dst}"
    code="$?"
    if [ $code -eq 0 ]; then
      return 0
    else
      local e="curl failed to download file, perhaps curl doesn't have"
      e="$e SSL support and/or no CA certificates are present?"
      warn "$e"
    fi
  fi

  # If we reach this point, wget and curl have failed and we're out of options
  exit_with "Required: SSL-enabled 'curl' or 'wget' on PATH with" 6
}

ensure_not_root() {
  need_cmd id

  if [ "$(id -u)" -eq 0 ]; then
    warn "$_program must be run as a non-root user, please re-run to try again."
    exit_with "Program run with root permissions" 1
  fi
}

get_sudo() {
  need_cmd sudo

  sudo -p "[sudo required for some tasks] Password for %u@${_hostname}: " -v
}

header() {
  case "${TERM:-}" in
    *term | xterm-* | rxvt | screen | screen-*)
      printf -- "\033[1;36m-----> \033[1;37m\033[40m${*}\033[0m\n"
      ;;
    *)
      printf -- "-----> $*\n"
      ;;
  esac
}

homedir_for() {
  local user="$1"
  local home
  case "$_system" in
    Darwin)
      need_cmd ruby

      home="$(ruby -retc -e "puts Etc.getpwnam('$user').dir")"
      ;;
    *)
      need_cmd cut
      need_cmd getent

      home="$(getent passwd "$user" | cut -d ':' -f 6)"
      ;;
  esac

  if [ -z "$home" ]; then
    warn "Could not find home for user $user"
    return 5
  else
    echo "$home"
    return 0
  fi
}

indent() {
  sed 's/^/       /'
}

info() {
  case "${TERM:-}" in
    *term | xterm-* | rxvt | screen | screen-*)
      printf -- "       \033[1;37m\033[40m${*:-}\033[0m\n"
      ;;
    *)
      printf -- "       ${*:-}\n"
      ;;
  esac
}

install_pkg() {
  case "$_os" in
    Darwin)
      darwin_install_pkg "$@"
      ;;
    Ubuntu)
      ubuntu_install_pkg "$@"
      ;;
    *)
      warn "Installing package on $_os not yet supported, skipping..."
      ;;
  esac
}

install_pkgs_from_json() {
  need_cmd cat
  need_cmd jq

  local json="$1"

  cat "$json" | jq -r .[] | while read -r pkg; do
    install_pkg "$pkg"
  done
}

# Keep-alive: update existing sudo time stamp if set, otherwise do nothing.
# See: https://gist.github.com/cowboy/3118588
keep_sudo() {
  need_cmd sudo

  while true; do
    sudo -n true; sleep 60; kill -0 "$$" || exit
  done 2>/dev/null &
}

need_cmd() {
  if ! command -v "$1" > /dev/null 2>&1; then
    exit_with "Required command '$1' not found on PATH" 127
  fi
}

warn() {
  case "${TERM:-}" in
    *term | xterm-* | rxvt | screen | screen-*)
      printf -- "\033[1;31m !!!   \033[1;37m\033[40m${*:-}\033[0m\n" >&2
      ;;
    *)
      printf -- " !!!   ${*:-}\n" >&2
      ;;
  esac
}
