#!/bin/bash
# Volume dropdown menu for Waybar using wofi
# Shows: output devices, input devices, and app volumes

ACTION="${1:-menu}"

get_icon() {
    local vol=$1
    local muted=$2
    if [[ "$muted" == "yes" ]] || [[ "$vol" -eq 0 ]]; then
        echo "󰖁"
    elif [[ "$vol" -lt 33 ]]; then
        echo "󰕿"
    elif [[ "$vol" -lt 66 ]]; then
        echo "󰖀"
    else
        echo "󰕾"
    fi
}

get_sink_volume() {
    pactl get-sink-volume @DEFAULT_SINK@ 2>/dev/null | grep -oP '\d+%' | head -1 | tr -d '%'
}

get_sink_muted() {
    pactl get-sink-mute @DEFAULT_SINK@ 2>/dev/null | grep -oP '(yes|no)'
}

list_sinks() {
    echo "󰕾 Output Devices"
    echo "---"
    pactl list short sinks 2>/dev/null | while read -r id rest; do
        name=$(echo "$rest" | awk '{print $2}')
        desc=$(pactl list sinks 2>/dev/null | grep -A20 "Sink #$id" | grep "Description:" | sed 's/.*Description: *//')
        vol=$(pactl list sinks 2>/dev/null | grep -A20 "Sink #$id" | grep "Volume:" | head -1 | grep -oP '\d+%' | head -1)
        muted=$(pactl list sinks 2>/dev/null | grep -A20 "Sink #$id" | grep "Mute:" | awk '{print $2}')
        is_default=""
        [[ "$name" == "$(pactl get-default-sink)" ]] && is_default=" ◀"
        icon=$(get_icon "${vol%%%}" "$muted")
        echo "$icon  $desc  $vol$is_default  →  set_sink $id"
    done
}

list_sources() {
    echo "󰍬 Input Devices"
    echo "---"
    pactl list short sources 2>/dev/null | while read -r id rest; do
        name=$(echo "$rest" | awk '{print $2}')
        [[ "$name" == *"monitor"* ]] && continue
        desc=$(pactl list sources 2>/dev/null | grep -A20 "Source #$id" | grep "Description:" | sed 's/.*Description: *//')
        vol=$(pactl list sources 2>/dev/null | grep -A20 "Source #$id" | grep "Volume:" | head -1 | grep -oP '\d+%' | head -1)
        muted=$(pactl list sources 2>/dev/null | grep -A20 "Source #$id" | grep "Mute:" | awk '{print $2}')
        is_default=""
        [[ "$name" == "$(pactl get-default-source)" ]] && is_default=" ◀"
        icon=$(get_icon "${vol%%%}" "$muted")
        echo "$icon  $desc  $vol$is_default  →  set_source $id"
    done
}

list_sink_inputs() {
    count=$(pactl list short sink-inputs 2>/dev/null | wc -l)
    [[ "$count" -eq 0 ]] && return
    echo "---"
    echo "  App Volumes"
    echo "---"
    pactl list short sink-inputs 2>/dev/null | while read -r id rest; do
        app=$(echo "$rest" | cut -d' ' -f3-)
        vol=$(pactl list sink-inputs 2>/dev/null | grep -A15 "Sink Input #$id" | grep "Volume:" | head -1 | grep -oP '\d+%' | head -1)
        icon=$(get_icon "${vol%%%}" "no")
        echo "$icon  $app  $vol  →  set_sink_input $id"
    done
}

set_sink() {
    pactl set-default-sink "$1"
    notify-send -t 2000 "Volume" "Switched output to sink $1"
}

set_source() {
    pactl set-default-source "$1"
    notify-send -t 2000 "Volume" "Switched input to source $1"
}

adjust_volume() {
    pactl set-sink-volume @DEFAULT_SINK@ "$1"
}

toggle_mute() {
    pactl set-sink-mute @DEFAULT_SINK@ toggle
}

make_slider() {
    local vol=$1
    local steps=("░░░░░░░░░░" "█░░░░░░░░░" "██░░░░░░░░" "███░░░░░░░" "████░░░░░░" "█████░░░░░" "██████░░░░" "███████░░░" "████████░░" "█████████░" "██████████")
    local idx=$((vol / 10))
    [[ $idx -gt 10 ]] && idx=10
    local bar="${steps[$idx]}"
    echo "  $bar  $vol%"
}

list_slider() {
    local current_vol=$(get_sink_volume)
    echo "  Volume"
    echo "---"
    for v in 0 10 20 30 40 50 60 70 80 90 100; do
        local marker=" "
        [[ "$v" -eq "$((current_vol / 10 * 10))" ]] && marker="▶"
        echo "  $marker $(make_slider $v)  →  set_vol $v"
    done
}

list_app_sliders() {
    count=$(pactl list short sink-inputs 2>/dev/null | wc -l)
    [[ "$count" -eq 0 ]] && return
    echo "---"
    echo "  App Volumes"
    echo "---"
    pactl list short sink-inputs 2>/dev/null | while read -r id rest; do
        app=$(echo "$rest" | cut -d' ' -f3-)
        vol=$(pactl list sink-inputs 2>/dev/null | grep -A15 "Sink Input #$id" | grep "Volume:" | head -1 | grep -oP '\d+%' | head -1)
        local vol_num=${vol%%%}
        local idx=$((vol_num / 10))
        [[ $idx -gt 10 ]] && idx=10
        local steps=("░░░░░░░░░░" "█░░░░░░░░░" "██░░░░░░░░" "███░░░░░░░" "████░░░░░░" "█████░░░░░" "██████░░░░" "███████░░░" "████████░░" "█████████░" "██████████")
        local bar="${steps[$idx]}"
        echo "    $app  $bar  $vol  →  set_sink_input_vol $id $vol_num"
    done
}

menu() {
    local current_vol=$(get_sink_volume)
    local current_icon=$(get_icon "$current_vol" "$(get_sink_muted)")

    local options=""
    options+=$'\n'$(list_slider)
    options+=$'\n'"---"
    options+=$'\n'"   $(get_icon 0 "$(get_sink_muted)")  Toggle Mute  →  mute"
    options+=$'\n'"---"
    options+=$'\n'$(list_sinks)
    options+=$'\n'$(list_sources)
    options+=$'\n'$(list_app_sliders)

    choice=$(echo "$options" | wofi --dmenu -p "  $current_icon Volume ($current_vol%)" -W 450 -H 600 --hide-scroll 2>/dev/null)

    [[ -z "$choice" ]] && exit 0

    cmd=$(echo "$choice" | grep -oP '→  \K.*')
    [[ -z "$cmd" ]] && exit 0

    action=$(echo "$cmd" | awk '{print $1}')
    arg1=$(echo "$cmd" | awk '{print $2}')
    arg2=$(echo "$cmd" | awk '{print $3}')

    case "$action" in
        set_vol)
            pactl set-sink-volume @DEFAULT_SINK@ "$arg1%"
            ;;
        adjust)
            adjust_volume "$arg"
            ;;
        mute)
            toggle_mute
            ;;
        set_sink)
            set_sink "$arg1"
            ;;
        set_source)
            set_source "$arg1"
            ;;
        set_sink_input)
            pactl set-sink-input-volume "$arg1" "$(get_sink_volume)%"
            ;;
        set_sink_input_vol)
            pactl set-sink-input-volume "$arg1" "$arg2%"
            ;;
    esac
}

case "$ACTION" in
    menu)
        menu
        ;;
    icon)
        vol=$(get_sink_volume)
        muted=$(get_sink_muted)
        icon=$(get_icon "$vol" "$muted")
        echo "{\"text\": \"$icon\", \"tooltip\": \"Volume: $vol%\"}"
        ;;
    pct)
        get_sink_volume
        ;;
    *)
        echo "Usage: $0 {menu|icon|pct}"
        exit 1
        ;;
esac
