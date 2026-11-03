#!/bin/bash

# GPU Detection and Configuration Script for MagikOS Installation
# This script detects available hardware and configures appropriate opencode settings

detect_gpu() {
    local gpu_type=""
    
    # Check for NVIDIA GPU
    if command -v nvidia-smi &> /dev/null; then
        gpu_type="nvidia"
        echo "NVIDIA GPU detected"
        return 0
    fi
    
    # Check for AMD GPU with ROCm
    if command -v rocminfo &> /dev/null; then
        local amdgpu_info=$(rocminfo | grep -i "gpu\|device" | head -1)
        if [[ "$amdgpu_info" =~ "gfx" ]]; then
            gpu_type="amd"
            echo "AMD GPU detected with ROCm support"
            return 0
        fi
    fi
    
    # Check for Intel GPU (Vulkan)
    if command -v vulkaninfo &> /dev/null; then
        # Simple check for Intel devices
        local intel_gpu=$(vulkaninfo | grep -i intel)
        if [[ -n "$intel_gpu" ]]; then
            gpu_type="intel"
            echo "Intel GPU detected with Vulkan support"
            return 0
        fi
    fi
    
    echo "No supported GPU detected, using CPU mode"
    return 1
}

# Main execution
echo "Detecting available GPU hardware..."
detect_gpu

echo "GPU detection complete."