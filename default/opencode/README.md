# OpenCode Configuration for MagikOS

This directory contains configuration files and scripts to properly set up OpenCode with GPU acceleration on AMD and NVIDIA systems.

## Files Included

### Environment Configuration
- `90-opencode-gpu.conf`: System-wide environment variables that enable ROCm/GPU acceleration for AMD GPUs

### Installation Scripts
- `gpu-detection.sh`: Detects available GPU hardware during installation
- `auto-config.sh`: Auto-configure OpenCode based on detected hardware
- `install-ollama.sh`: Installs Ollama with appropriate models
- `hardware-specific-config.sh`: Configures OpenCode for specific hardware setups

## Hardware Support

### AMD GPUs (ROCm)
For systems with AMD Radeon GPUs like RX 6700 XT:
- Uses `ROCR_VISIBLE_DEVICES=all` 
- Sets `HSA_OVERRIDE_GFX_VERSION=10.3.1` for proper compatibility
- Automatically enables GPU acceleration through ROCm

### NVIDIA GPUs
For systems with NVIDIA GTX 1650 and similar:
- Configures for CUDA acceleration using appropriate model variants
- Supports `llama3.2:1b-instruct-nvidia` model optimization

## Installation Integration

These configurations are automatically applied during MagikOS installation process through:
1. System-wide environment variables in `/etc/environment.d/`
2. Auto-configuration during user provisioning 
3. Ollama model installation with hardware-appropriate models for Ryzen 5 4600H + GTX 1650 setups

## Usage

After installation, OpenCode will automatically use:
- GPU acceleration when available (ROCm or CUDA)
- Appropriate agentic models based on detected hardware capabilities
- System-wide environment configuration ensures optimal performance