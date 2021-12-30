#!/usr/bin/env sh
# shellcheck disable=SC3043

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

arch_setup_package_system() {
  indent sudo pacman -Sy --noconfirm
  arch_build_paru
}

arch_update_system() {
  indent sudo pacman -Su --noconfirm
  indent paru -Su --noconfirm

  if [ -x /usr/bin/upgrade-kernel ]; then
    indent sudo /usr/bin/upgrade-kernel
  fi
}

arch_install_base_packages() {
  local data_path="$1"

  install_pkg jq
  install_pkgs_from_json "$data_path/arch_base_pkgs.json"
}

arch_install_headless_packages() {
  local data_path="$1"

  install_pkgs_from_json "$data_path/arch_headless_pkgs.json"
  arch_install_aur_pkgs_from_json "$data_path/arch_headless_aur_pkgs.json"
}

arch_finalize_headless_setup() {
  local svc

  # As prescribed by System76's support article for Arch Linux
  #
  # See: https://support.system76.com/articles/system76-software
  if [ "$(cat /sys/class/dmi/id/product_name)" = "Thelio Major" ]; then
    need_cmd getent

    arch_install_aur_pkg system76-driver
    svc=system76
    arch_enable_service "$svc"
    arch_start_service "$svc"

    if ! getent group adm | grep -q "$USER"; then
      need_cmd gpasswd

      info "Adding '$USER' to adm group"
      indent sudo gpasswd -a "$USER" adm
    fi

    svc=system76-firmware-daemon
    arch_install_aur_pkg "$svc"
    arch_enable_service "$svc"

    arch_install_aur_pkg firmware-manager
    arch_install_aur_pkg system76-dkms
    arch_install_aur_pkg system76-io-dkms

    svc=system76-power
    arch_install_aur_pkg "$svc"
    arch_enable_service "$svc"
    arch_start_service "$svc"

    arch_install_aur_pkg pm-utils
  fi

  svc=tailscaled.service
  if [ -f "/usr/lib/systemd/system/$svc" ]; then
    arch_enable_service "$svc"
    arch_start_service "$svc"
  fi
}

arch_install_graphical_packages() {
  local data_path="$1"

  install_pkgs_from_json "$data_path/arch_graphical_pkgs.json"
  arch_install_aur_pkgs_from_json "$data_path/arch_graphical_aur_pkgs.json"
  # TODO: determine how to swap between Wayland and Xorg
  install_pkgs_from_json "$data_path/arch_graphical_xorg_pkgs.json"
}

arch_finalize_graphical_setup() {
  local svc

  if [ "$(cat /sys/class/dmi/id/product_name)" = "XPS 13 9370" ]; then
    need_cmd cut
    need_cmd getent
    need_cmd grep

    # Battery status
    install_pkg acpi

    # Setup power management
    install_pkg powertop
    if [ ! -f /etc/systemd/system/powertop.service ]; then
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

      arch_enable_service powertop
      arch_start_service powertop
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
    # Required for copy and pasting between the host and guest
    install_pkg gtkmm3
    install_pkg libxtst
    install_pkg xf86-input-vmmouse
    # Required for autofit guest screen resolution for both Xorg & Wayland
    # See: https://bugs.archlinux.org/task/57473
    install_pkg xf86-video-vmware

    arch_enable_service vmware-vmblock-fuse.service
    arch_start_service vmware-vmblock-fuse.service
  fi

  if grep -q '^#greeter-session=' /etc/lightdm/lightdm.conf; then
    info "Initializing lightdm greeter-session"
    sudo sed -i -e 's|^#\(greeter-session\)=\(.*\)$|\1=\2|' \
      /etc/lightdm/lightdm.conf
  fi
  if ! grep -q '^greeter-session=lightdm-webkit2-greeter$' \
    /etc/lightdm/lightdm.conf; then
    info "Setting lightdm greeter"
    sudo sed -i -e 's|^\(greeter-session\)=.*$|\1=lightdm-webkit2-greeter|' \
      /etc/lightdm/lightdm.conf
  fi
  if grep -q '^#user-session=' /etc/lightdm/lightdm.conf; then
    info "Initializing lightdm user-session"
    sudo sed -i -e 's|^#\(user-session\)=\(.*\)$|\1=\2|' \
      /etc/lightdm/lightdm.conf
  fi
  if ! grep -q '^user-session=regolith$' \
    /etc/lightdm/lightdm.conf; then
    info "Setting lightdm user-session"
    sudo sed -i -e 's|^\(user-session\)=.*$|\1=regolith|' \
      /etc/lightdm/lightdm.conf
  fi
  if ! grep -q -E '^webkit_theme\s*=\s*litarvan$' \
    /etc/lightdm/lightdm-webkit2-greeter.conf; then
    info "Configuring lightdm-webkit2-greeter"
    sudo sed -i -e 's|^\(webkit_theme *\)=.*$|\1= litarvan|' \
      /etc/lightdm/lightdm-webkit2-greeter.conf
  fi
  svc=lightdm.service
  if [ -f "/usr/lib/systemd/system/$svc" ]; then
    arch_enable_service "$svc"
  fi

  svc=NetworkManager.service
  if [ -f "/usr/lib/systemd/system/$svc" ]; then
    arch_enable_service "$svc"
    arch_start_service "$svc"
  fi

  svc=cups.service
  if [ -f "/usr/lib/systemd/system/$svc" ]; then
    arch_enable_service "$svc"
    arch_start_service "$svc"
  fi

  local xinitrc_d=/etc/X11/xinit/xinitrc.d/90-gnome-keyring-daemon.sh
  if [ ! -f "$xinitrc_d" ]; then
    need_cmd chmod
    need_cmd tee

    info "Creating '$xinitrc_d'"
    cat <<-'EOF' | sudo tee "$xinitrc_d" >/dev/null
	#!/bin/sh

	if [ -x /usr/bin/gnome-keyring-daemon ]; then
	  eval $(/usr/bin/gnome-keyring-daemon --start --components=pkcs11,secrets,ssh)
	  export SSH_AUTH_SOCK
	fi
	EOF
    sudo chmod 0755 "$xinitrc_d"
  fi

  if ! grep -q 'pam_gnome_keyring.so auto_start$' /etc/pam.d/login; then
    need_cmd awk
    need_cmd install

    local tmp_login
    tmp_login="$(mktemp_file)"
    cleanup_file "$tmp_login"

    info "Starting gnome-keyring in PAM at console login"
    awk '
      /^auth *include *system-local-login$/ {
        print
        print "auth       optional     pam_gnome_keyring.so"
        next
      }
      /^password *include *system-local-login$/ {
        print
        print "session    optional     pam_gnome_keyring.so auto_start"
        next
      }
      { print }
    ' /etc/pam.d/login >"$tmp_login"
    sudo install -m 644 -o root -g root "$tmp_login" /etc/pam.d/login
  fi
}

arch_build_paru() {
  need_cmd pacman

  if pacman -Qi paru >/dev/null 2>&1; then
    return 0
  fi

  sudo pacman -S --noconfirm --needed base-devel git

  local build_dir
  build_dir="$(mktemp_directory)"
  cleanup_directory "$build_dir"

  info "Installing Paru package"
  indent git clone https://aur.archlinux.org/paru-bin.git "$build_dir"
  (cd "$build_dir" && makepkg --syncdeps --install --noconfirm --clean)
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
  need_cmd paru

  info "Installing AUR package '$pkg'"
  indent paru -S --noconfirm "$pkg"
}

arch_install_aur_pkgs_from_json() {
  local json="$1"

  json_items "$json" | while read -r pkg; do
    arch_install_aur_pkg "$pkg"
  done
}

arch_enable_service() {
  local svc="$1"

  need_cmd sudo
  need_cmd systemctl

  if ! systemctl is-enabled "$svc" >/dev/null; then
    info "Enabling '$svc' service"
    indent sudo systemctl enable "$svc"
  fi
}

arch_start_service() {
  local svc="$1"

  need_cmd sudo
  need_cmd systemctl

  if ! systemctl is-active "$svc" >/dev/null; then
    info "Starting '$svc' service"
    indent sudo systemctl start "$svc"
  fi
}
