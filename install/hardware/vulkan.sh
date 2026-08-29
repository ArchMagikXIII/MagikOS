# Install Vulkan drivers matching detected GPU hardware
# (NVIDIA Vulkan is handled by nvidia.sh via nvidia-utils)

source "$MAGIKOS_PATH/bin/magikos-pkg-backend"

VULKAN_DRIVERS[Intel]=vulkan-intel
VULKAN_DRIVERS[AMD]=vulkan-radeon
VULKAN_DRIVERS[Apple]=vulkan-asahi

PACKAGES=()

for vendor in "${!VULKAN_DRIVERS[@]}"; do
  if lspci | grep -iE "(VGA|Display).*$vendor" > /dev/null; then
    PACKAGES+=("${VULKAN_DRIVERS[$vendor]}")
  fi
done

if (( ${#PACKAGES[@]} > 0 )); then
  magikos-pkg-add "${PACKAGES[@]}"
fi
