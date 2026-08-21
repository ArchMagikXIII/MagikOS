#!/usr/bin/env bash

# GPU usage script for Waybar
# Supports NVIDIA (nvidia-smi) and AMD (sysfs)

get_nvidia() {
    if command -v nvidia-smi &>/dev/null; then
        local query
        query=$(nvidia-smi --query-gpu=name,utilization.gpu,memory.used,memory.total,temperature.gpu --format=csv,noheader,nounits 2>/dev/null)
        if [ -n "$query" ]; then
            IFS=',' read -r name util mem_used mem_total temp <<< "$query"
            name=$(echo "$name" | xargs)
            util=$(echo "$util" | xargs)
            mem_used=$(echo "$mem_used" | xargs)
            mem_total=$(echo "$mem_total" | xargs)
            temp=$(echo "$temp" | xargs)
            
            echo "{\"text\": \"${util}%\","
            echo "\"tooltip\": \"${name}\\nUsage: ${util}%\\nVRAM: ${mem_used} / ${mem_total} MiB\\nTemp: ${temp}°C\","
            echo "\"class\": \"nvidia\"}"
            return 0
        fi
    fi
    return 1
}

get_amd() {
    for card in /sys/class/drm/card*; do
        if [ -f "$card/device/gpu_busy_percent" ]; then
            local util vram_used_mb vram_total_mb temp_c
            util=$(cat "$card/device/gpu_busy_percent" 2>/dev/null || echo 0)
            
            if [ -f "$card/device/mem_info_vram_used" ]; then
                local raw_used raw_total
                raw_used=$(cat "$card/device/mem_info_vram_used" 2>/dev/null || echo 0)
                raw_total=$(cat "$card/device/mem_info_vram_total" 2>/dev/null || echo 0)
                vram_used_mb=$((raw_used / 1024 / 1024))
                vram_total_mb=$((raw_total / 1024 / 1024))
            else
                vram_used_mb=0
                vram_total_mb=0
            fi

            local temp_file
            temp_file=$(ls "$card/device/hwmon/hwmon"*/temp1_input 2>/dev/null | head -n1)
            if [ -n "$temp_file" ] && [ -f "$temp_file" ]; then
                local raw_temp
                raw_temp=$(cat "$temp_file" 2>/dev/null || echo 0)
                temp_c=$((raw_temp / 1000))
            else
                temp_c=0
            fi

            echo "{\"text\": \"${util}%\","
            echo "\"tooltip\": \"AMD Radeon Graphics (${card##*/})\\nUsage: ${util}%\\nVRAM: ${vram_used_mb} / ${vram_total_mb} MiB\\nTemp: ${temp_c}°C\","
            echo "\"class\": \"amd\"}"
            return 0
        fi
    done
    return 1
}

# Try NVIDIA first if available, then AMD
if command -v nvidia-smi &>/dev/null && nvidia-smi &>/dev/null; then
    get_nvidia
elif ! get_amd; then
    echo "{\"text\": \"N/A\", \"tooltip\": \"No compatible GPU found\", \"class\": \"none\"}"
fi
