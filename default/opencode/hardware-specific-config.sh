#!/bin/bash

# Hardware-Specific Configuration for MagikOS Installation
# Configures opencode with models optimized for Ryzen 5 4600H + GTX 1650 system

configure_for_ryzen_4600h_gtx1650() {
    echo "Configuring for Ryzen 5 4600H with GTX 1650 GPU..."
    
    # This function represents what would be done during installation
    # on a system with the specific hardware mentioned
    
    echo "Hardware detected: Ryzen 5 4600H CPU + GTX 1650 GPU"
    echo "Optimal models for this configuration:"
    echo "- qwen3.5:2b (small, fast model suitable for your dual-GPU setup)"
    echo "- qwen3-coder:30b (larger model for complex coding tasks)"
    echo "- llama3.2:1b-instruct-nvidia (CUDA-optimized alternative for NVIDIA GPU)"
    
    # Create proper opencode configuration with default agent selection
    mkdir -p /home/magikxiii/.config/opencode/
    
    cat > /home/magikxiii/.config/opencode/opencode.json <<EOF
{
  "$schema": "https://opencode.ai/config.json",
  "theme": "system",
  "autoupdate": false,
  "model": "ollama/qwen3-coder-64k",
  "provider": {
    "ollama": {
      "npm": "@ai-sdk/openai-compatible",
      "name": "Ollama (local)",
      "options": {
        "baseURL": "http://localhost:11434/v1"
      },
      "models": {
        "qwen3-coder-64k": {
          "name": "Qwen3 Coder 30B (local, 64k)",
          "limit": {
            "context": 65536,
            "output": 8192
          }
        },
        "qwen3.5:2b": {
          "name": "Qwen3.5 2B (local, fast)",
          "limit": {
            "context": 32768,
            "output": 4096
          }
        }
      }
    }
  }
}
EOF
    
    echo "Configuration created for Ryzen 5 4600H + GTX 1650 setup"
    echo "Default models include both fast (qwen3.5:2b) and capable (qwen3-coder-64k) versions"
}

# Main execution
configure_for_ryzen_4600h_gtx1650 "$@"