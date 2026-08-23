if lspci | grep -qi 'nvidia'; then
  source "$MAGIKOS_PATH/bin/magikos-pkg-backend"

  # Driver sets are named per distribution; the GPU capability split is shared.
  if backend_is_pacman; then
    # Check which kernel is installed and set appropriate headers package
    KERNEL_PACKAGE=$(pacman -Qqs '^linux(-zen|-lts|-hardened|-t2|-ptl)?$' | head -1 || true)
    [[ -n $KERNEL_PACKAGE ]] && magikos-pkg-add "$KERNEL_PACKAGE-headers"

    if magikos-hw-nvidia-gsp; then
      PACKAGES=(nvidia-open-dkms nvidia-utils lib32-nvidia-utils libva-nvidia-driver)
    elif magikos-hw-nvidia-without-gsp; then
      PACKAGES=(nvidia-580xx-dkms nvidia-580xx-utils lib32-nvidia-580xx-utils)
    fi
  else
    # RPM Fusion ships prebuilt kmods built at install time by akmods, which
    # needs the devel tree matching the running kernel. There is no 580xx
    # legacy branch here, so pre-GSP GPUs fall through to the bail below.
    PACKAGES_DEVEL=(kernel-devel kernel-headers)

    if magikos-hw-nvidia-gsp; then
      PACKAGES=(akmod-nvidia xorg-x11-drv-nvidia libva-nvidia-driver "${PACKAGES_DEVEL[@]}")
    fi
  fi

  # Bail if no supported GPU
  if [[ -z ${PACKAGES+x} ]]; then
    echo "No compatible driver for your NVIDIA GPU. See: https://wiki.archlinux.org/title/NVIDIA"
    exit 0
  fi

  magikos-pkg-add "${PACKAGES[@]}"

  # Configure modprobe for early KMS
  mkdir -p /etc/modprobe.d
  cat > /etc/modprobe.d/nvidia.conf <<'EOF'
options nvidia_drm modeset=1
EOF

  # Configure the initramfs generator for early loading; each distribution has
  # its own, and neither picks NVIDIA modules up by default.
  if backend_is_pacman; then
    mkdir -p /etc/mkinitcpio.conf.d
    cat > /etc/mkinitcpio.conf.d/nvidia.conf <<'EOF'
MODULES+=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)
EOF
  else
    mkdir -p /etc/dracut.conf.d
    cat > /etc/dracut.conf.d/nvidia.conf <<'EOF'
add_drivers+=" nvidia nvidia_modeset nvidia_uvm nvidia_drm "
EOF

    # The conf file alone changes nothing until an image is generated.
    if command -v dracut >/dev/null 2>&1; then
      dracut -f --regenerate-all || true
    fi
  fi
fi
