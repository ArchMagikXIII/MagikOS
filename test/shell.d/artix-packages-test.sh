#!/bin/bash
set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/base-test.sh"

manifest="$ROOT/install/magikos-base-artix-openrc.packages"
[[ -f $manifest ]] || fail "Artix OpenRC package manifest exists"
mapfile -t packages < <(sed -e '/^[[:space:]]*#/d' -e '/^[[:space:]]*$/d' "$manifest")
(( ${#packages[@]} > 0 && ${#packages[@]} < 90 )) || fail "Artix manifest is a curated list, not the full Arch manifest"

has_package() { printf '%s\n' "${packages[@]}" | grep -Fxq -- "$1"; }

for package in "${packages[@]}"; do
  [[ $package =~ ^[a-z0-9][a-z0-9@._+-]*$ ]] || fail "Artix manifest has only plain package names" "$package"
done
[[ $(printf '%s\n' "${packages[@]}" | sort -u | wc -l) -eq ${#packages[@]} ]] || fail "Artix manifest has no duplicate packages"
pass "Artix manifest is compact, parseable, and duplicate-free"

for package in sway swaybg swayidle swaylock foot fuzzel quickshell qt6-wayland \
               thunar wl-clipboard xdg-desktop-portal xdg-desktop-portal-gtk \
               xdg-desktop-portal-wlr xorg-xwayland \
               grim slurp flameshot; do
  has_package "$package" || fail "Artix manifest ships essential Sway session packages" "Missing $package"
done
pass "Artix manifest ships the desktop, launcher, portal, and available screenshot tools"

for package in dbus-openrc elogind-openrc bluez bluez-openrc; do
  has_package "$package" || fail "Artix manifest ships verified OpenRC system service packages" "Missing $package"
done
for package in networkmanager networkmanager-openrc ufw ufw-openrc power-profiles-daemon power-profiles-daemon-openrc; do
  ! has_package "$package" || fail "Artix adoption preserves host network, firewall and power policy" "$package"
done
pass "Artix manifest ships session services without replacing host networking, firewall or power policy"

for package in pipewire wireplumber \
               pipewire-openrc wireplumber-openrc; do
  has_package "$package" || fail "Artix manifest ships PipeWire user services" "Missing $package"
done
for package in pipewire-alsa pipewire-pulse pipewire-pulse-openrc; do
  ! has_package "$package" || fail "Artix adoption must not replace an existing PulseAudio setup" "$package"
done
pass "Artix manifest ships core PipeWire services without forcing PulseAudio replacement"

for package in "${packages[@]}"; do
  case $package in
    cachyos-*|cachy-*|linux*|*nvidia*|*limine*|*grub*|*systemd*|uwsm|mkinitcpio|efibootmgr|os-prober|swappy|satty|sddm|sddm-openrc|seatd-openrc|yay|bpftune-git|brave-origin-bin|topgrade-bin)
      fail "Artix manifest leaves the host boot stack, login manager, and vendor extras alone" "$package" ;;
  esac
done
pass "Artix manifest avoids boot replacement, systemd-only sessions, and unverified extras"

for description in cachyos linux-cachyos linux-omarchy uwsm screenshot sddm; do
  grep -Fiq -- "$description" "$manifest" || fail "Artix manifest documents intentional omissions" "$description"
done
pass "Artix manifest documents what is deliberately omitted"
