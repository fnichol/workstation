#!/bin/sh
# shellcheck shell=sh disable=SC2039
#
# Implementation drawn from `sh-realpath`: a portable, pure shell
# implementation of realpath. Modified:
#
# * Add support to work with `set -e`
# * Add shellcheck ignore for `local`
# * Apply consistent code formatting via `shfmt -i 2 -ci -bn`
# * Remove removed portable `readlink` implementation.
#
# Original Source:
#
# * Fork: https://github.com/mkropat/sh-realpath/blob/bb72bec5370fa5905cebb47e91937dd25d96d0d7/realpath.sh
# * See: https://github.com/mkropat/sh-realpath
#
# Original license:
#
# The MIT License (MIT)
#
# Copyright (c) 2014 Michael Kropat

# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:

# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

realpath() {
  canonicalize_path "$(resolve_symlinks "$1")"
}

resolve_symlinks() {
  _resolve_symlinks "$1"
}

_resolve_symlinks() {
  _assert_no_path_cycles "$@" || return

  local dir_context path
  if path=$(readlink -- "$1"); then
    dir_context=$(dirname -- "$1")
    _resolve_symlinks \
      "$(_prepend_dir_context_if_necessary "$dir_context" "$path")" "$@"
  else
    printf '%s\n' "$1"
  fi
}

_prepend_dir_context_if_necessary() {
  if [ "$1" = . ]; then
    printf '%s\n' "$2"
  else
    _prepend_path_if_relative "$1" "$2"
  fi
}

_prepend_path_if_relative() {
  case "$2" in
    /*) printf '%s\n' "$2" ;;
    *) printf '%s\n' "$1/$2" ;;
  esac
}

_assert_no_path_cycles() {
  local target path

  target=$1
  shift

  for path in "$@"; do
    if [ "$path" = "$target" ]; then
      return 1
    fi
  done
}

canonicalize_path() {
  if [ -d "$1" ]; then
    _canonicalize_dir_path "$1"
  else
    _canonicalize_file_path "$1"
  fi
}

_canonicalize_dir_path() {
  (cd "$1" 2>/dev/null && pwd -P)
}

_canonicalize_file_path() {
  local dir file
  dir=$(dirname -- "$1")
  file=$(basename -- "$1")
  (cd "$dir" 2>/dev/null && printf '%s/%s\n' "$(pwd -P)" "$file")
}
