#!/usr/bin/env sh
# shellcheck disable=SC2039

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

openbsd_install_headless_packages() {
  local data_path="$1"

  install_pkgs_from_json "$data_path/openbsd_headless_pkgs.json"
}

openbsd_install_rust() {
  install_pkg rust
  install_pkg rust-clippy
  install_pkg rust-gdb
  install_pkg rust-rustfmt
}

openbsd_install_node() {
  install_pkg node
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
