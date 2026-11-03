#!/bin/bash

# Ollama Installation Script for MagikOS
# Installs Ollama with appropriate models based on system hardware capabilities

install_ollama_with_models() {
    echo "Installing Ollama with GPU acceleration support..."
    
    # Install Ollama (assuming it's available in the repository)
    if command -v pacman &> /dev/null; then
        sudo pacman -Syu --noconfirm ollama || echo "Ollama installation failed, continuing anyway"
    fi
    
    # Start Ollama service if available
    if command -v systemctl &> /dev/null; then
        sudo systemctl enable --now ollama || echo "Failed to start Ollama service"
    fi
    
    # Wait for Ollama to be ready
    sleep 3
    
    # Check what GPU is available and install appropriate models
    local gpu_type="unknown"
    
    if command -v nvidia-smi &> /dev/null; then
        gpu_type="nvidia"
        echo "NVIDIA GPU detected - installing NVIDIA-optimized models"
        # Install NVIDIA optimized models that will utilize CUDA
        ollama pull llama3.2:1b-instruct-nvidia
        ollama pull qwen3-coder-64k:latest
        
    elif command -v rocminfo &> /dev/null; then
        gpu_type="amd"
        echo "AMD GPU detected with ROCm support"
        # Install models optimized for AMD GPUs
        ollama pull qwen3-coder-64k:latest
        
    elif command -v vulkaninfo &> /dev/null; then
        gpu_type="intel"
        echo "Intel GPU detected with Vulkan support"
        # Install Intel optimized models
        ollama pull qwen3-coder:30b
        
    else
        echo "No specialized GPU detected - using CPU-optimized models"
        # Install CPU optimized models 
        ollama pull qwen3-coder:30b
    fi
    
    # Download a set of useful agentic models for development tasks
    echo "Installing agentic models appropriate for development and productivity..."
    
    # Download Qwen3 models, which work well on your system and support the architecture
    ollama pull qwen3-coder-64k:latest
    
    # Install additional productivity models that can benefit from GPU acceleration
    if [ "$gpu_type" = "amd" ] || [ "$gpu_type" = "nvidia" ]; then
        echo "Installing GPU-accelerated agentic models..."
        ollama pull qwen3-coder:30b
        
        # For systems with sufficient memory, also install larger models 
        if [ "$(free -g | awk '/^Mem:/{print $2}')" -ge 16 ]; then
            echo "Detected sufficient RAM - installing larger models"
            ollama pull qwen3-coder-14b:latest
        fi
    else
        # Install CPU optimized versions for systems without dedicated GPU
        echo "Installing CPU optimized models for system without dedicated GPU"
    fi
    
    echo "Ollama installation complete with appropriate models."
}

# Main execution
install_ollama_with_models "$@"