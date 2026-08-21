#!/usr/bin/env bash

# AMD Integrated GPU usage script for Waybar

card=""
for c in /sys/class/drm/card*; do
    if [ -f "$c/device/gpu_busy_percent" ]; then
        card="$c"
        break
    fi
done

if [ -n "$card" ]; then
    util=$(cat "$card/device/gpu_busy_percent" 2>/dev/null || echo 0)
    raw_used=$(cat "$card/device/mem_info_vram_used" 2>/dev/null || echo 0)
    raw_total=$(cat "$card/device/mem_info_vram_total" 2>/dev/null || echo 0)
    vram_used=$((raw_used / 1024 / 1024))
    vram_total=$((raw_total / 1024 / 1024))
    
    temp_file=$(ls "$card/device/hwmon/hwmon"*/temp1_input 2>/dev/null | head -n1)
    if [ -n "$temp_file" ] && [ -f "$temp_file" ]; then
        raw_temp=$(cat "$temp_file" 2>/dev/null || echo 0)
        temp=$((raw_temp / 1000))
    else
        temp=0
    fi

    printf '{"text": "AMD %s%%", "tooltip": "AMD Radeon Vega Graphics\\nUsage: %s%%\\nVRAM: %s / %s MiB\\nTemp: %s°C", "class": "amd"}\n' \
        "$util" "$util" "$vram_used" "$vram_total" "$temp"
    exit 0
fi

printf '{"text": "AMD OFF", "tooltip": "AMD GPU not found", "class": "offline"}\n'
