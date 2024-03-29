#!/usr/bin/env sh
# shellcheck disable=SC3043

# BEGIN: libsh.sh

#
# Copyright 2019 Fletcher Nichol and/or applicable contributors.
#
# Licensed under the Apache License, Version 2.0 <LICENSE-APACHE or
# http://www.apache.org/licenses/LICENSE-2.0> or the MIT license (see
# <LICENSE-MIT or http://opensource.org/licenses/MIT>, at your option. This
# file may not be copied, modified, or distributed except according to those
# terms.
#
# libsh.sh
# --------
# project: https://github.com/fnichol/libsh
# author: Fletcher Nichol <fnichol@nichol.ca>
# version: 0.10.1
# distribution: libsh.full.sh
# commit-hash: 46134771903ba66967666ca455f73ffc10dd0a03
# commit-date: 2021-05-08
# artifact: https://github.com/fnichol/libsh/releases/download/v0.10.1/libsh.full.sh
# source: https://github.com/fnichol/libsh/tree/v0.10.1
# archive: https://github.com/fnichol/libsh/archive/v0.10.1.tar.gz
#

if [ -n "${KSH_VERSION:-}" ]; then
  # Evil, nasty, wicked hack to ignore calls to `local <var>`, on the strict
  # assumption that no initialization will take place, i.e. `local
  # <var>=<value>`. If this assumption holds, this implementation fakes a
  # `local` keyword for ksh. The `eval` is used as some versions of dash will
  # error with "Syntax error: Bad function name" whether or not it's in a
  # conditional (likely in the parser/ast phase) (src:
  # https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=619786). Also, `shfmt`
  # does *not* like a function called `local` so...another dodge here. TBD on
  # this one, folks...
  eval "local() { return 0; }"
fi

# Creates a temporary directory and prints the name to standard output.
#
# Most system use the first no-argument version, however Mac OS X 10.10
# (Yosemite) and older don't allow the no-argument version, hence the second
# fallback version.
#
# All tested invocations will create a file in each platform's suitable
# temporary directory.
#
# * `@param [optional, String]` parent directory
# * `@stdout` path to temporary directory
# * `@return 0` if successful
#
# # Examples
#
# Basic usage:
#
# ```sh
# dir="$(mktemp_directory)"
# # use directory
# ```
#
# With a custom parent directory:
#
# ```sh
# dir="$(mktemp_directory "$HOME")"
# # use directory
# ```

# shellcheck disable=SC2120
mktemp_directory() {
  need_cmd mktemp

  if [ -n "${1:-}" ]; then
    mktemp -d "$1/tmp.XXXXXX"
  else
    mktemp -d 2>/dev/null || mktemp -d -t tmp
  fi
}

# Creates a temporary file and prints the name to standard output.
#
# Most systems use the first no-argument version, however Mac OS X 10.10
# (Yosemite) and older don't allow the no-argument version, hence the second
# fallback version.

# All tested invocations will create a file in each platform's suitable
# temporary directory.
#
# * `@param [optional, String]` parent directory
# * `@stdout` path to temporary file
# * `@return 0` if successful
#
# # Examples
#
# Basic usage:
#
# ```sh
# file="$(mktemp_file)"
# # use file
# ```
#
# With a custom parent directory:
#
# ```sh
# dir="$(mktemp_file $HOME)"
# # use file
# ```

# shellcheck disable=SC2120
mktemp_file() {
  need_cmd mktemp

  if [ -n "${1:-}" ]; then
    mktemp "$1/tmp.XXXXXX"
  else
    mktemp 2>/dev/null || mktemp -t tmp
  fi
}

# Removes any tracked files registered via [`cleanup_file`].
#
# * `@return 0` whether or not an error has occurred
#
# [`cleanup_file`]: #cleanup_file
#
# # Global Variables
#
# * `__CLEANUP_FILES__` used to track the collection of files to clean up whose
#   value is a file. If not declared or set, this function will assume there is
#   no work to do.
#
# # Examples
#
# Basic usage:
#
# ```sh
# trap trap_cleanup_files 1 2 3 15 ERR EXIT
#
# file="$(mktemp_file)"
# cleanup_file "$file"
# # do work on file, etc.
# ```
trap_cleanup_files() {
  set +e

  if [ -n "${__CLEANUP_FILES__:-}" ] && [ -f "$__CLEANUP_FILES__" ]; then
    local _file
    while read -r _file; do
      rm -f "$_file"
    done <"$__CLEANUP_FILES__"
    unset _file
    rm -f "$__CLEANUP_FILES__"
  fi
}

# Prints an error message and exits with a non-zero code if the program is not
# available on the system PATH.
#
# * `@param [String]` program name
# * `@stderr` a warning message is printed if program cannot be found
#
# # Environment Variables
#
# * `PATH` indirectly used to search for the program
#
# # Notes
#
# If the program is not found, this function calls `exit` and will **not**
# return.
#
# # Examples
#
# Basic usage, when used as a guard or prerequisite in a function:
#
# ```sh
# need_cmd git
# ```
need_cmd() {
  if ! check_cmd "$1"; then
    die "Required command '$1' not found on PATH"
  fi
}

# Removes any tracked files and directories registered via [`cleanup_file`]
# and [`cleanup_directory`] respectively.
#
# * `@return 0` whether or not an error has occurred
#
# [`cleanup_directory`]: #cleanup_directory
# [`cleanup_file`]: #cleanup_file
#
# # Examples
#
# Basic usage:
#
# ```sh
# trap trap_cleanups 1 2 3 15 ERR EXIT
# ```
#
# Used with [`setup_traps`]:
#
# ```sh
# setup_traps trap_cleanups
# ```
#
# [`setup_traps`]: #setup_traps
trap_cleanups() {
  set +e

  trap_cleanup_directories
  trap_cleanup_files
}

# Prints program version information to standard out.
#
# The minimal implementation will output the program name and version,
# separated with a space, such as `my-program 1.2.3`. However, if the Git
# program is detected and the current working directory is under a Git
# repository, then more information will be displayed. Namely, the short Git
# SHA and author commit date will be appended in parenthesis at end of the
# line. For example, `my-program 1.2.3 (abc123 2000-01-02)`. Alternatively, if
# the Git commit information is known ahead of time, it can be provided via
# optional arguments.
#
# If verbose mode is enable by setting the optional third argument to a
# `true`, then a detailed version report will be appended to the
# single line "simple mode". Assuming that the Git program is available and the
# current working directory is under a Git repository, then three extra lines
# will be emitted:
#
# 1. `release: 1.2.3` the version string
# 2. `commit-hash: abc...` the full Git SHA of the current commit
# 3. `commit-date: 2000-01-02` the author commit date of the current commit
#
# If Git is not found and no additional optional arguments are provided, then
# only the `release: 1.2.3` line will be emitted for verbose mode.
#
# Finally, if the Git repository is not "clean", that is if it contains
# uncommitted or modified files, a `-dirty` suffix will be added to the short
# and long Git SHA refs to signal that the implementation may not perfectly
# correspond to a SHA commit.
#
# * `@param [String]` program name
# * `@param [String]` version string
# * `@param [optional, String]` verbose mode set if value if `"true"`
# * `@param [optional, String]` short Git SHA
# * `@param [optional, String]` long Git SHA
# * `@param [optional, String]` commit/version date
# * `@stdout` version information
# * `@return 0` if successful
#
# Note that the implementation for this function was inspired by Rust's [`cargo
# version`](https://git.io/fjsOh).
#
# # Examples
#
# Basic usage:
#
# ```sh
# print_version "my-program" "1.2.3"
# ```
#
# An optional third argument puts the function in verbose mode and more detail
# is output to standard out:
#
# ```sh
# print_version "my-program" "1.2.3" "true"
# ```
#
# An empty third argument is the same as only providing two arguments (i.e.
# non-verbose):
#
# ```sh
# print_version "my-program" "1.2.3" ""
# ```
print_version() {
  local _program _version _verbose _sha _long_sha _date
  _program="$1"
  _version="$2"
  _verbose="${3:-false}"
  _sha="${4:-}"
  _long_sha="${5:-}"
  _date="${6:-}"

  if [ -z "$_sha" ] || [ -z "$_long_sha" ] || [ -z "$_date" ]; then
    if check_cmd git \
      && git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
      if [ -z "$_sha" ]; then
        _sha="$(git show -s --format=%h)"
        if ! git diff-index --quiet HEAD --; then
          _sha="${_sha}-dirty"
        fi
      fi
      if [ -z "$_long_sha" ]; then
        _long_sha="$(git show -s --format=%H)"
        case "$_sha" in
          *-dirty) _long_sha="${_long_sha}-dirty" ;;
        esac
      fi
      if [ -z "$_date" ]; then
        _date="$(git show -s --format=%ad --date=short)"
      fi
    fi
  fi

  if [ -n "$_sha" ] && [ -n "$_date" ]; then
    echo "$_program $_version ($_sha $_date)"
  else
    echo "$_program $_version"
  fi

  if [ "$_verbose" = "true" ]; then
    echo "release: $_version"
    if [ -n "$_long_sha" ]; then
      echo "commit-hash: $_long_sha"
    fi
    if [ -n "$_date" ]; then
      echo "commit-date: $_date"
    fi
  fi

  unset _program _version _verbose _sha _long_sha _date
}

# Prints a warning message to standard out.
#
# * `@param [String]` warning text
# * `@stdout` warning heading text
# * `@return 0` if successful
#
# # Environment Variables
#
# * `TERM` used to determine whether or not the terminal is capable of printing
#   colored output.
#
# # Examples
#
# Basic usage:
#
# ```sh
# warn "Could not connect to service"
# ```
warn() {
  case "${TERM:-}" in
    *term | alacritty | rxvt | screen | screen-* | tmux | tmux-* | xterm-*)
      printf -- "\033[1;31;40m!!! \033[1;37;40m%s\033[0m\n" "$1"
      ;;
    *)
      printf -- "!!! %s\n" "$1"
      ;;
  esac
}

# Prints a section-delimiting header to standard out.
#
# * `@param [String]` section heading text
# * `@stdout` section heading text
# * `@return 0` if successful
#
# # Environment Variables
#
# * `TERM` used to determine whether or not the terminal is capable of printing
#   colored output.
#
# # Examples
#
# Basic usage:
#
# ```sh
# section "Building project"
# ```
section() {
  case "${TERM:-}" in
    *term | alacritty | rxvt | screen | screen-* | tmux | tmux-* | xterm-*)
      printf -- "\033[1;36;40m--- \033[1;37;40m%s\033[0m\n" "$1"
      ;;
    *)
      printf -- "--- %s\n" "$1"
      ;;
  esac
}

# Sets up state to track directories for later cleanup in a trap handler.
#
# This function is typically used in combination with [`cleanup_directory`] and
# [`trap_cleanup_directories`].
#
# * `@return 0` if successful
# * `@return 1` if a temp file could not be created
#
# # Global Variables
#
# * `__CLEANUP_DIRECTORIES__` used to track the collection of directories to
# clean up whose value is a file. If not declared or set, this function will
# set it up.
# * `__CLEANUP_DIRECTORIES_SETUP__` used to track if the
# `__CLEANUP_DIRECTORIES__` variable has been set up for the current process
#
# # Examples
#
# Basic usage:
#
# ```sh
# setup_cleanup_directories
# ```
#
# Used with [`cleanup_directory`], [`setup_traps`], and
# [`trap_cleanup_directories`]:
#
# ```sh
# setup_cleanup_directories
# setup_traps trap_cleanup_directories
#
# dir="$(mktemp_directory)"
# cleanup_directory "$dir"
# # do work on directory, etc.
# ```
#
# [`cleanup_file`]: #cleanup_file
# [`setup_traps`]: #setup_traps
# [`trap_cleanup_directories`]: #trap_cleanup_directories
setup_cleanup_directories() {
  if [ "${__CLEANUP_DIRECTORIES_SETUP__:-}" != "$$" ]; then
    unset __CLEANUP_DIRECTORIES__
    __CLEANUP_DIRECTORIES_SETUP__="$$"
    export __CLEANUP_DIRECTORIES_SETUP__
  fi

  # If a tempfile hasn't been setup yet, create it
  if [ -z "${__CLEANUP_DIRECTORIES__:-}" ]; then
    __CLEANUP_DIRECTORIES__="$(mktemp_file)"

    # If the result string is empty, tempfile wasn't created so report failure
    if [ -z "$__CLEANUP_DIRECTORIES__" ]; then
      return 1
    fi

    export __CLEANUP_DIRECTORIES__
  fi
}

# Sets up state to track files for later cleanup in a trap handler.
#
# This function is typically used in combination with [`cleanup_file`] and
# [`trap_cleanup_files`].
#
# * `@return 0` if successful
# * `@return 1` if a temp file could not be created
#
# # Global Variables
#
# * `__CLEANUP_FILES__` used to track the collection of files to clean up whose
#   value is a file. If not declared or set, this function will set it up.
# * `__CLEANUP_FILES_SETUP__` used to track if the `__CLEANUP_FILES__`
# variable has been set up for the current process
#
# # Examples
#
# Basic usage:
#
# ```sh
# setup_cleanup_files
# ```
#
# Used with [`cleanup_file`], [`setup_traps`], and [`trap_cleanup_files`]:
#
# ```sh
# setup_cleanup_files
# setup_traps trap_cleanup_files
#
# file="$(mktemp_file)"
# cleanup_file "$file"
# # do work on file, etc.
# ```
#
# [`cleanup_file`]: #cleanup_file
# [`setup_traps`]: #setup_traps
# [`trap_cleanup_files`]: #trap_cleanup_files
setup_cleanup_files() {
  if [ "${__CLEANUP_FILES_SETUP__:-}" != "$$" ]; then
    unset __CLEANUP_FILES__
    __CLEANUP_FILES_SETUP__="$$"
    export __CLEANUP_FILES_SETUP__
  fi

  # If a tempfile hasn't been setup yet, create it
  if [ -z "${__CLEANUP_FILES__:-}" ]; then
    __CLEANUP_FILES__="$(mktemp_file)"

    # If the result string is empty, tempfile wasn't created so report failure
    if [ -z "$__CLEANUP_FILES__" ]; then
      return 1
    fi

    export __CLEANUP_FILES__
  fi
}

# Sets up state to track files and directories for later cleanup in a trap
# handler.
#
# This function is typically used in combination with [`cleanup_file`] and
# [`cleanup_directory`] as well as [`trap_cleanups`].
#
# * `@return 0` if successful
# * `@return 1` if the setup was not successful
#
# # Examples
#
# Basic usage:
#
# ```sh
# setup_cleanups
# ```
#
# Used with [`cleanup_directory`], [`cleanup_file`], [`setup_traps`], and
# [`trap_cleanups`]:
#
# ```sh
# setup_cleanups
# setup_traps trap_cleanups
#
# file="$(mktemp_file)"
# cleanup_file "$file"
# # do work on file, etc.
#
# dir="$(mktemp_directory)"
# cleanup_directory "$dir"
# # do work on directory, etc.
# ```
#
# [`cleanup_directory`]: #cleanup_directory
# [`cleanup_file`]: #cleanup_file
# [`setup_traps`]: #setup_traps
# [`trap_cleanups`]: #trap_cleanups
setup_cleanups() {
  setup_cleanup_directories
  setup_cleanup_files
}

# Sets up traps for `EXIT` and common signals with the given cleanup function.
#
# In addition to `EXIT`, the `HUP`, `INT`, `QUIT`, `ALRM`, and `TERM` signals
# are also covered.
#
# This implementation was based on a very nice, portable signal handling thread
# thanks to an implementation on
# [Stack Overflow](https://unix.stackexchange.com/a/240736).
#
# * `@param [String]` name of function to run with traps
#
# # Examples
#
# Basic usage with a simple "hello world" cleanup function:
#
# ```sh
# hello_trap() {
#   echo "Hello, trap!"
# }
#
# setup_traps hello_trap
# ```
#
# If the cleanup is simple enough to be a one-liner, you can provide the
# command as the single argument:
#
# ```sh
# setup_traps "echo 'Hello, World!'"
# ```
setup_traps() {
  local _sig
  for _sig in HUP INT QUIT ALRM TERM; do
    trap "
      $1
      trap - $_sig EXIT
      kill -s $_sig "'"$$"' "$_sig"
  done

  if [ -n "${ZSH_VERSION:-}" ]; then
    # Zsh uses the `EXIT` trap for a function if declared in a function.
    # Instead, use the `zshexit()` hook function which targets the exiting of a
    # shell interpreter. Additionally, a function in Zsh is not a closure over
    # outer variables, so we'll use `eval` to construct the function body
    # containing the cleanup function to invoke.
    #
    # See:
    # * https://stackoverflow.com/a/22794374
    # * http://zsh.sourceforge.net/Doc/Release/Functions.html#Hook-Functions
    eval "zshexit() { eval '$1'; }"
  else
    # shellcheck disable=SC2064
    trap "$1" EXIT
  fi

  unset _sig
}

# Removes any tracked directories registered via [`cleanup_directory`].
#
# * `@return 0` whether or not an error has occurred
#
# [`cleanup_directory`]: #cleanup_directory
#
# # Global Variables
#
# * `__CLEANUP_DIRECTORIES__` used to track the collection of files to clean up
#   whose value is a file. If not declared or set, this function will assume
#   there is no work to do.
#
# # Examples
#
# Basic usage:
#
# ```sh
# trap trap_cleanup_directories 1 2 3 15 ERR EXIT
#
# dir="$(mktemp_directory)"
# cleanup_directory "$dir"
# # do work on directory, etc.
# ```
trap_cleanup_directories() {
  set +e

  if [ -n "${__CLEANUP_DIRECTORIES__:-}" ] \
    && [ -f "$__CLEANUP_DIRECTORIES__" ]; then
    local _dir
    while read -r _dir; do
      rm -rf "$_dir"
    done <"$__CLEANUP_DIRECTORIES__"
    unset _dir
    rm -f "$__CLEANUP_DIRECTORIES__"
  fi
}

# Determines whether or not a program is available on the system PATH.
#
# * `@param [String]` program name
# * `@return 0` if program is found on system PATH
# * `@return 1` if program is not found
#
# # Environment Variables
#
# * `PATH` indirectly used to search for the program
#
# # Examples
#
# Basic usage, when used as a conditional check:
#
# ```sh
# if check_cmd git; then
#   echo "Found Git"
# fi
# ```
check_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    return 1
  fi
}

# Tracks a directory for later cleanup in a trap handler.
#
# This function can be called immediately after a temp directory is created,
# before a directory is created, or long after a directory exists. When used in
# combination with [`trap_cleanup_directories`], all directories registered by
# calling `cleanup_directory` will be removed if they exist when
# `trap_cleanup_directories` is invoked.
#
# * `@param [String]` path to directory
# * `@return 0` if successful
# * `@return 1` if a temp file could not be created
#
# [`trap_cleanup_directories`]: #trap_cleanup_directories
#
# # Global Variables
#
# * `__CLEANUP_DIRECTORIES__` used to track the collection of directories to
#   clean up whose value is a file. If not declared or set, this function will
#   set it up.
#
# # Examples
#
# Basic usage:
#
# ```sh
# dir="$(mktemp_directory)"
# cleanup_directory "$dir"
# # do work on directory, etc.
# ```
cleanup_directory() {
  setup_cleanup_directories
  echo "$1" >>"$__CLEANUP_DIRECTORIES__"
}

# Tracks a file for later cleanup in a trap handler.
#
# This function can be called immediately after a temp file is created, before
# a file is created, or long after a file exists. When used in combination with
# [`trap_cleanup_files`], all files registered by calling `cleanup_file` will
# be removed if they exist when `trap_cleanup_files` is invoked.
#
# * `@param [String]` path to file
# * `@return 0` if successful
# * `@return 1` if a temp file could not be created
#
# [`trap_cleanup_files`]: #trap_cleanup_files
#
# # Global Variables
#
# * `__CLEANUP_FILES__` used to track the collection of files to clean up whose
#   value is a file. If not declared or set, this function will set it up.
#
# # Examples
#
# Basic usage:
#
# ```sh
# file="$(mktemp_file)"
# cleanup_file "$file"
# # do work on file, etc.
# ```
cleanup_file() {
  setup_cleanup_files
  echo "$1" >>"$__CLEANUP_FILES__"
}

# Prints an error message to standard error and exits with a non-zero exit
# code.
#
# * `@param [String]` warning text
# * `@stderr` warning text message
#
# # Environment Variables
#
# * `TERM` used to determine whether or not the terminal is capable of printing
#   colored output.
#
# # Notes
#
# This function calls `exit` and will **not** return.
#
# # Examples
#
# Basic usage:
#
# ```sh
# die "No program to download tarball"
# ```
die() {
  case "${TERM:-}" in
    *term | alacritty | rxvt | screen | screen-* | tmux | tmux-* | xterm-*)
      printf -- "\n\033[1;31;40mxxx \033[1;37;40m%s\033[0m\n\n" "$1" >&2
      ;;
    *)
      printf -- "\nxxx %s\n\n" "$1" >&2
      ;;
  esac

  exit 1
}

# Downloads the contents at the given URL to the given local file.
#
# This implementation attempts to use the `curl` program with a fallback to the
# `wget` program and a final fallback to the `ftp` program. The first download
# program to succeed is used and if all fail, this function returns a non-zero
# code.
#
# * `@param [String]` download URL
# * `@param [String]` destination file
# * `@return 0` if a download was successful
# * `@return 1` if a download was not successful
#
# # Notes
#
# At least one of `curl`, `wget`, or `ftp` must be compiled with SSL/TLS
# support to be able to download from `https` sources.
#
# # Examples
#
# Basic usage:
#
# ```sh
# download http://example.com/file.txt /tmp/file.txt
# ```
download() {
  local _url _dst _code _orig_flags
  _url="$1"
  _dst="$2"

  need_cmd sed

  # Attempt to download with curl, if found. If successful, quick return
  if check_cmd curl; then
    info "Downloading $_url to $_dst (curl)"
    _orig_flags="$-"
    set +e
    curl -sSfL "$_url" -o "$_dst"
    _code="$?"
    set "-$(echo "$_orig_flags" | sed s/s//g)"
    if [ $_code -eq 0 ]; then
      unset _url _dst _code _orig_flags
      return 0
    else
      local _e
      _e="curl failed to download file, perhaps curl doesn't have"
      _e="$_e SSL support and/or no CA certificates are present?"
      warn "$_e"
      unset _e
    fi
  fi

  # Attempt to download with wget, if found. If successful, quick return
  if check_cmd wget; then
    info "Downloading $_url to $_dst (wget)"
    _orig_flags="$-"
    set +e
    wget -q -O "$_dst" "$_url"
    _code="$?"
    set "-$(echo "$_orig_flags" | sed s/s//g)"
    if [ $_code -eq 0 ]; then
      unset _url _dst _code _orig_flags
      return 0
    else
      local _e
      _e="wget failed to download file, perhaps wget doesn't have"
      _e="$_e SSL support and/or no CA certificates are present?"
      warn "$_e"
      unset _e
    fi
  fi

  # Attempt to download with ftp, if found. If successful, quick return
  if check_cmd ftp; then
    info "Downloading $_url to $_dst (ftp)"
    _orig_flags="$-"
    set +e
    ftp -o "$_dst" "$_url"
    _code="$?"
    set "-$(echo "$_orig_flags" | sed s/s//g)"
    if [ $_code -eq 0 ]; then
      unset _url _dst _code _orig_flags
      return 0
    else
      local _e
      _e="ftp failed to download file, perhaps ftp doesn't have"
      _e="$_e SSL support and/or no CA certificates are present?"
      warn "$_e"
      unset _e
    fi
  fi

  unset _url _dst _code _orig_flags
  # If we reach this point, curl, wget and ftp have failed and we're out of
  # options
  warn "Downloading requires SSL-enabled 'curl', 'wget', or 'ftp' on PATH"
  return 1
}

# Indents the output from a command while preserving the command's exit code.
#
# In minimal/POSIX shells there is no support for `set -o pipefail` which means
# that the exit code of the first command in a shell pipeline won't be
# addressable in an easy way. This implementation uses a temp file to ferry the
# original command's exit code from a subshell back into the main function. The
# output can be aligned with a pipe to `sed` as before but now we have an
# implementation which mimics a `set -o pipefail` which should work on all
# Bourne shells. Note that the `set -o errexit` is disabled during the
# command's invocation so that its exit code can be captured.
#
# Based on implementation from [Stack
# Overflow](https://stackoverflow.com/a/54931544)
#
# * `@param [String[]]` command and arguments
# * `@return` the exit code of the command which was executed
#
# # Notes
#
# In order to preserve the output order of the command, the `stdout` and
# `stderr` streams are combined, so the command will not emit its `stderr`
# output to the caller's `stderr` stream.
#
# # Examples
#
# Basic usage:
#
# ```sh
# indent cat /my/file
# ```
indent() {
  local _ecfile _ec _orig_flags

  need_cmd cat
  need_cmd rm
  need_cmd sed

  _ecfile="$(mktemp_file)"

  _orig_flags="$-"
  set +e
  {
    "$@" 2>&1
    echo "$?" >"$_ecfile"
  } | sed 's/^/       /'
  set "-$(echo "$_orig_flags" | sed s/s//g)"
  _ec="$(cat "$_ecfile")"
  rm -f "$_ecfile"

  unset _ecfile _orig_flags
  return "${_ec:-5}"
}

# Prints an informational, detailed step to standard out.
#
# * `@param [String]` informational text
# * `@stdout` informational heading text
# * `@return 0` if successful
#
# # Environment Variables
#
# * `TERM` used to determine whether or not the terminal is capable of printing
#   colored output.
#
# # Examples
#
# Basic usage:
#
# ```sh
# info "Downloading tarball"
# ```
info() {
  case "${TERM:-}" in
    *term | alacritty | rxvt | screen | screen-* | tmux | tmux-* | xterm-*)
      printf -- "\033[1;36;40m  - \033[1;37;40m%s\033[0m\n" "$1"
      ;;
    *)
      printf -- "  - %s\n" "$1"
      ;;
  esac
}

# Completes printing an informational, detailed step to standard out which has
# no output, started with `info_start`
#
# * `@stdout` informational heading text
# * `@return 0` if successful
#
# # Environment Variables
#
# * `TERM` used to determine whether or not the terminal is capable of printing
#   colored output.
#
# # Examples
#
# Basic usage:
#
# ```sh
# info_end
# ```
info_end() {
  case "${TERM:-}" in
    *term | alacritty | rxvt | screen | screen-* | tmux | tmux-* | xterm-*)
      printf -- "\033[1;37;40m%s\033[0m\n" "done."
      ;;
    *)
      printf -- "%s\n" "done."
      ;;
  esac
}

# Prints an informational, detailed step to standard out which has no output.
#
# * `@param [String]` informational text
# * `@stdout` informational heading text
# * `@return 0` if successful
#
# # Environment Variables
#
# * `TERM` used to determine whether or not the terminal is capable of printing
#   colored output.
#
# # Examples
#
# Basic usage:
#
# ```sh
# info_start "Copying file"
# ```
info_start() {
  case "${TERM:-}" in
    *term | alacritty | rxvt | screen | screen-* | tmux | tmux-* | xterm-*)
      printf -- "\033[1;36;40m  - \033[1;37;40m%s ... \033[0m" "$1"
      ;;
    *)
      printf -- "  - %s ... " "$1"
      ;;
  esac
}

# END: libsh.sh
