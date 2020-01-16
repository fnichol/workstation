#!/usr/bin/env sh
# shellcheck disable=SC2039

arch_set_hostname() {
  need_cmd grep
  need_cmd hostnamectl
  need_cmd sed
  need_cmd sudo
  need_cmd tee

  local name="$1"
  local fqdn="$2"

  local old_hostname
  old_hostname="$(hostnamectl --static)"

  if [ "$old_hostname" != "$name" ]; then
    echo "$name" | sudo tee /etc/hostname >/dev/null
    sudo hostnamectl set-hostname "$name"
    if ! grep -q -w "$fqdn" /etc/hosts; then
      sudo sed -i "1i 127.0.0.1\\t${fqdn}\\t${name}" /etc/hosts
    fi
  fi
}

arch_install_headless_packages() {
  local data_path="$1"

  install_pkgs_from_json "$data_path/arch_headless_pkgs.json"
  arch_build_yay
  arch_install_aur_pkgs_from_json "$data_path/arch_headless_aur_pkgs.json"
}

arch_install_graphical_packages() {
  local data_path="$1"

  install_pkgs_from_json "$data_path/arch_graphical_pkgs.json"
  arch_install_aur_pkgs_from_json "$data_path/arch_graphical_aur_pkgs.json"
  # TODO: determine how to swap between Wayland and Xorg
  install_pkgs_from_json "$data_path/arch_graphical_xorg_pkgs.json"
}

arch_finalize_graphical_setup() {
  need_cmd ln
  need_cmd sudo

  sudo ln -snf /etc/fonts/conf.avail/11-lcdfilter-default.conf \
    /etc/fonts/conf.d
  sudo ln -snf /etc/fonts/conf.avail/10-sub-pixel-rgb.conf \
    /etc/fonts/conf.d
  sudo ln -snf /etc/fonts/conf.avail/30-infinality-aliases.conf \
    /etc/fonts/conf.d

  if [ "$(cat /sys/class/dmi/id/product_name)" = "XPS 13 9370" ]; then
    need_cmd cut
    need_cmd getent
    need_cmd grep

    # Battery status
    install_pkg acpi

    # Setup power management
    install_pkg powertop
    if [ ! -f /etc/systemd/system/powertop.service ]; then
      need_cmd systemctl

      info "Setting up Powertop for power management tuning"
      cat <<-'EOF' | sudo tee /etc/systemd/system/powertop.service >/dev/null
	[Unit]
	Description=Powertop tunings

	[Service]
	ExecStart=/usr/bin/powertop --auto-tune
	RemainAfterExit=true

	[Install]
	WantedBy=multi-user.target
	EOF

      info "Enabling and starting 'powertop' service"
      sudo systemctl enable powertop
      sudo systemctl start powertop
    fi

    if [ ! -f /etc/udev/rules.d/backlight.rules ]; then
      info "Setting up udev backlight rule"
      cat <<-'EOF' | sudo tee /etc/udev/rules.d/backlight.rules >/dev/null
	ACTION=="add", SUBSYSTEM=="backlight", KERNEL=="intel_backlight", RUN+="/bin/chgrp video /sys/class/backlight/%k/brightness"
	ACTION=="add", SUBSYSTEM=="backlight", KERNEL=="intel_backlight", RUN+="/bin/chmod g+w /sys/class/backlight/%k/brightness"
	EOF
    fi

    if ! getent group video | cut -d : -f 4 | grep -q "$USER"; then
      need_cmd sudo
      need_cmd usermod

      info "Adding $USER to the video group"
      sudo usermod --append --groups video "$USER"
    fi
  fi

  if [ "$(cat /sys/class/dmi/id/sys_vendor)" = "VMware, Inc." ]; then
    need_cmd systemctl

    # Required for copy and pasting between the host and guest
    install_pkg gtkmm3
    install_pkg libxtst
    install_pkg xf86-input-vmmouse
    # Required for autofit guest screen resolution for both Xorg & Wayland
    # See: https://bugs.archlinux.org/task/57473
    install_pkg xf86-video-vmware

    info "Enabling and starting 'vmware-vmblock-fuse' service"
    sudo systemctl enable vmware-vmblock-fuse.service
    sudo systemctl start vmware-vmblock-fuse.service
  fi
}

arch_build_yay() {
  need_cmd pacman

  if pacman -Qi yay >/dev/null 2>&1; then
    return 0
  fi

  need_cmd git
  need_cmd makepkg
  need_cmd mktemp

  local build_dir
  build_dir="$(mktemp -d /tmp/yay.XXXXXXXX)"

  info "Building yay package"
  git clone https://aur.archlinux.org/yay.git "$build_dir/yay"
  (cd "$build_dir/yay" && makepkg --syncdeps --install --noconfirm --clean)

  rm -rf "$build_dir"
}

arch_install_pkg() {
  need_cmd pacman

  local pkg="$1"

  if pacman -Qi "$pkg" >/dev/null 2>&1; then
    # This is a package and it is installed
    return 0
  fi

  if pacman -Sg "$pkg" >/dev/null 2>&1; then
    # This is a package group, so ensure each package is installed
    pacman -Sg "$pkg" \
      | cut -d ' ' -f 2 \
      | while read -r p; do arch_install_pkg "$p" || return 1; done
    return 0
  fi

  need_cmd sudo

  info "Installing package '$pkg'"
  indent sudo pacman -S --noconfirm "$pkg"
}

arch_install_aur_pkg() {
  need_cmd pacman

  local pkg="$1"

  if pacman -Qi "$pkg" >/dev/null 2>&1; then
    return 0
  fi

  need_cmd sudo
  need_cmd yay

  info "Installing AUR package '$pkg'"
  indent yay -S --noconfirm "$pkg"
}

arch_install_aur_pkgs_from_json() {
  local json="$1"

  json_items "$json" | while read -r pkg; do
    arch_install_aur_pkg "$pkg"
  done
}
