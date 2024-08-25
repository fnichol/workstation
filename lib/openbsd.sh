#!/usr/bin/env sh
# shellcheck disable=SC3043

openbsd_set_hostname() {
  local fqdn="$1"

  need_cmd doas
  need_cmd tee

  doas hostname "$fqdn"
  echo "$fqdn" | doas tee /etc/myname >/dev/null
}

openbsd_update_system() {
  need_cmd doas
  need_cmd pkg_add

  indent doas pkg_add -u
}

openbsd_install_base_packages() {
  local data_path="$1"

  install_pkg jq
  install_pkgs_from_json "$data_path/openbsd_base_pkgs.json"
}

openbsd_finalize_base_setup() {
  openbsd_install_alacritty_terminfo
}

openbsd_install_alacritty_terminfo() {
  need_cmd infocmp

  if ! infocmp alacritty >/dev/null 2>&1; then
    local alacrity_info
    alacrity_info="$(mktemp_file)"
    cleanup_file "$alacrity_info"

    info "Adding alacritty to terminfo"
    download \
      https://raw.githubusercontent.com/alacritty/alacritty/master/extra/alacritty.info \
      "$alacrity_info"
    indent doas tic -xe alacritty,alacritty-direct "$alacrity_info"
  fi
}

openbsd_install_headless_packages() {
  local data_path="$1"

  install_pkgs_from_json "$data_path/openbsd_headless_pkgs.json"
}

openbsd_install_rust() {
  install_pkg rust
  install_pkg rust-analyzer
  install_pkg rust-clippy
  install_pkg rust-gdb
  install_pkg rust-rustfmt
  install_pkg rust-src
}

openbsd_install_node() {
  install_pkg node
}

openbsd_install_graphical_packages() {
  local data_path="$1"

  openbsd_install_xenocara
  install_pkgs_from_json "$data_path/openbsd_graphical_pkgs.json"
  install_pkgs_from_json "$data_path/openbsd_graphical_xorg_pkgs.json"
}

openbsd_install_xenocara() {
  if [ -x /usr/X11R6/bin/xterm ]; then
    return 0
  fi

  need_cmd rm
  need_cmd sed
  need_cmd tar
  need_cmd uname

  local url suffix tgz tmptgz
  suffix="$(uname -r | sed 's/\.//g').tgz"

  url="$(cat /etc/installurl)"
  url="$url/$(uname -r)"
  url="$url/$(uname -m)"

  for tgz in xbase xfont xserv xshare; do
    tmptgz="$(mktemp_file)"
    cleanup_file "$tmptgz"
    download "$url/$tgz$suffix" "$tmptgz"
    info "Extracting $tgz$suffix"
    doas tar xzphf "$tmptgz" -C /
    rm -f "$tmptgz"
  done
}

openbsd_install_pkg() {
  local pkg="$1"

  need_cmd pkg_add
  need_cmd pkg_info
  need_cmd grep

  local pkg_stem pkg_version pkg_flavor
  eval "$(openbsd_pkg_parts "$pkg")"

  local pkg_spec
  if [ -z "$pkg_version" ]; then
    pkg_spec="$pkg_stem->0-$pkg_flavor"
  else
    pkg_spec="$pkg_stem-$pkg_version-$pkg_flavor"
  fi

  local output
  if output="$(pkg_info -e "$pkg_spec")"; then
    local grep_expr
    if [ -n "$pkg_flavor" ]; then
      grep_expr="^inst:$pkg_stem-[0-9].*-$pkg_flavor$"
    else
      grep_expr="^inst:$pkg_stem-[0-9][^-]*$"
    fi

    if echo "$output" | grep -q "$grep_expr" >/dev/null; then
      return 0
    fi
  fi

  info "Installing package '$pkg'"
  indent doas pkg_add -Iv "$pkg"
}

openbsd_pkg_parts() {
  local name="$1"

  need_cmd perl

  perl -- - "$name" <<-'EOF'
	my $name = shift;

        if ($name =~ /^(.*?)-(\d[^-]*)?(?:-([^-]*)?)?$/) {
	  my $stem = $1;
	  my $version = $2 || "";
	  my $flavor = $3 || "";

	  print "pkg_stem='", $stem, "'\n";
	  print "pkg_version='", $version, "'\n";
	  print "pkg_flavor='", $flavor, "'\n";
	} else {
	  print "pkg_stem='", $name, "'\n";
	  print "pkg_version=''\n";
	  print "pkg_flavor=''\n";
	}
	EOF
}
