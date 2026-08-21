#!/usr/bin/env bash

# NVIDIA GPU usage script for Waybar

if command -v nvidia-smi &>/dev/null; then
    query=$(nvidia-smi --query-gpu=name,utilization.gpu,memory.used,memory.total,temperature.gpu --format=csv,noheader,nounits 2>/dev/null)
    if [ -n "$query" ]; then
        IFS=',' read -r name util mem_used mem_total temp <<< "$query"
        name=$(echo "$name" | xargs)
        util=$(echo "$util" | xargs)
        mem_used=$(echo "$mem_used" | xargs)
        mem_total=$(echo "$mem_total" | xargs)
        temp=$(echo "$temp" | xargs)
        
        printf '{"text": "NV %s%%", "tooltip": "%s\\nUsage: %s%%\\nVRAM: %s / %s MiB\\nTemp: %s°C", "class": "nvidia"}\n' \
            "$util" "$name" "$util" "$mem_used" "$mem_total" "$temp"
        exit 0
    fi
fi

printf '{"text": "NV OFF", "tooltip": "NVIDIA GPU offline / asleep", "class": "offline"}\n'
