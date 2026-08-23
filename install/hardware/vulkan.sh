# Install Vulkan drivers matching detected GPU hardware
# (NVIDIA Vulkan is handled by nvidia.sh via nvidia-utils)

source "$MAGIKOS_PATH/bin/magikos-pkg-backend"

declare -A VULKAN_DRIVERS=()

if backend_is_pacman; then
  VULKAN_DRIVERS[Intel]=vulkan-intel
  VULKAN_DRIVERS[AMD]=vulkan-radeon
  VULKAN_DRIVERS[Apple]=vulkan-asahi
else
  # Mesa's drivers cover Intel, AMD/Radeon, and Apple Asahi alike; only the
  # 32-bit companion is named separately.
  VULKAN_DRIVERS[Intel]=mesa-vulkan-drivers
  VULKAN_DRIVERS[AMD]=mesa-vulkan-drivers
  VULKAN_DRIVERS[Apple]=mesa-vulkan-drivers
fi

PACKAGES=()

for vendor in "${!VULKAN_DRIVERS[@]}"; do
  if lspci | grep -iE "(VGA|Display).*$vendor" > /dev/null; then
    PACKAGES+=("${VULKAN_DRIVERS[$vendor]}")
  fi
done

if (( ${#PACKAGES[@]} > 0 )); then
  magikos-pkg-add "${PACKAGES[@]}"
fi
