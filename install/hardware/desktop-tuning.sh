# Desktop performance tuning for Magikos installations.
#
# Auto-detects system capabilities and applies optimizations that are safe
# for the detected hardware. This runs on every installation.

# --- CPU Governor ---
# Set CPU governor to performance on AC power for lower latency.
# Only applies to systems with cpufreq support (most desktops and laptops).
if [[ -d /sys/devices/system/cpu/cpufreq ]]; then
  cat > /etc/udev/rules.d/99-magikos-cpu-performance.rules << 'EOF'
# Set CPU governor to performance on AC power
ACTION=="add", SUBSYSTEM=="cpu", TEST=="cpufreq", ATTR{cpufreq/scaling_governor}="performance"

# Also set on power supply change to AC
ACTION=="change", SUBSYSTEM=="power_supply", ATTR{type}=="Mains", ATTR{online}=="1", RUN+="/bin/sh -c 'echo performance > /sys/devices/system/cpu/cpufreq/policy*/scaling_governor'"
EOF
  udevadm control --reload 2>/dev/null || true
  udevadm trigger --subsystem-match=power_supply 2>/dev/null || true
fi

# --- Sysctl Tuning ---
# Apply desktop-optimized kernel parameters.
cat > /etc/sysctl.d/99-magikos-desktop-tuning.conf << 'EOF'
# Magikos desktop tuning

# BBR congestion control: better throughput and latency than cubic
net.ipv4.tcp_congestion_control = bbr

# Network buffer sizes
net.core.rmem_max = 8388608
net.core.wmem_max = 8388608

# Reduce vfs_cache_pressure to keep dentries/inodes cached longer
vm.vfs_cache_pressure = 30
EOF
sysctl --system 2>/dev/null || true

# --- ext4 noatime ---
# Add noatime to ext4 mounts to reduce write overhead.
# Only modifies fstab entries that don't already have noatime.
if [[ -f /etc/fstab ]]; then
  # Check if any ext4 mount is missing noatime
  if grep -E '^[^#].*ext4' /etc/fstab | grep -qv 'noatime'; then
    sed -i '/ext4/ s/relatime/noatime/g; /ext4/ s/rw,/rw,noatime,/g' /etc/fstab
  fi
fi
