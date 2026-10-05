# Install Vulkan drivers matching detected GPU hardware
# (NVIDIA Vulkan is handled by nvidia.sh via nvidia-utils)

source "$MAGIKOS_PATH/bin/magikos-pkg-backend"

PACKAGES=()

# Detect GPU vendor from lspci and install the matching Vulkan driver
if lspci | grep -iE "(VGA|Display).*Intel" > /dev/null; then
  PACKAGES+=("vulkan-intel")
fi

if lspci | grep -iE "(VGA|Display).*AMD" > /dev/null; then
  PACKAGES+=("vulkan-radeon")
fi

# Only install vulkan-asahi on actual Apple Silicon (M1/M2/M3/M4)
if lspci | grep -iE "(VGA|Display).*Apple" > /dev/null; then
  PACKAGES+=("vulkan-asahi")
fi

if (( ${#PACKAGES[@]} > 0 )); then
  magikos-pkg-add "${PACKAGES[@]}"
fi
