#!/bin/bash

set -euo pipefail

# env vars with defaults
WATCH_DIR="${WATCH_DIR:-/input}"
TROUBLE_DIR="${TROUBLE_DIR:-/trouble}"
TMP_DIR="/tmp"
TROUBLE_MAX_AGE="${TROUBLE_MAX_AGE:-86400}"

PIPE="${PIPE:-/tmp/mqtt_pipe}"
MQTT_HOST="${MQTT_HOST:-localhost}"
MQTT_PORT="${MQTT_PORT:-1883}"
MQTT_CLIENT_ID="${MQTT_CLIENT_ID:-}"
MQTT_TOPIC="${MQTT_TOPIC:-your/topic}"
MQTT_USERNAME="${MQTT_USERNAME:-}"
MQTT_PASSWORD="${MQTT_PASSWORD:-}"

mkdir -p "$TROUBLE_DIR"

# setup core dump directory and pattern
mkdir -p /cores
ulimit -c unlimited

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') $*"
}

# MQTT publisher setup
if [[ ! -p "$PIPE" ]]; then
    log "Creating named pipe at $PIPE"
    mkfifo "$PIPE"
fi

start_mqtt_ppd() {
    log "Starting mqtt-ppd for MQTT publishing."

    while true; do
        CMD=(/usr/bin/mqtt-ppd "$MQTT_HOST" "$MQTT_TOPIC" "$MQTT_PORT")

        if [[ -n "$MQTT_USERNAME" ]]; then
            CMD+=("$MQTT_USERNAME")
        fi

        if [[ -n "$MQTT_PASSWORD" ]]; then
            CMD+=("$MQTT_PASSWORD")
        fi

        if [[ -n "$MQTT_CLIENT_ID" ]]; then
            CMD+=("$MQTT_CLIENT_ID")
        fi

        log "mqtt-ppd command: ${CMD[*]}"

        "${CMD[@]}" < "$PIPE"
        log "mqtt-ppd exited, retrying in 5 seconds..."
        sleep 5
    done
}

if pgrep -f "mqtt-ppd.*$PIPE" > /dev/null; then
    log "mqtt-ppd already running, skipping start."
else
    start_mqtt_ppd &
    PUB_PID=$!
fi

exec 3>"$PIPE"

trap "log 'Stopping mqtt-ppd (PID $PUB_PID)'; kill $PUB_PID 2>/dev/null; exit" INT TERM

publish_mqtt() {
    local message="$1"
    echo "$message" >&3
}

publish_mqtt_file() {
    local file="$1"
    jq -c . "$file" >&3
    rm -f "$file"
}

invert_image() { convert "$1" -negate "$2"; }

grayscale_image() { convert "$1" -colorspace Gray "$2"; }

threshold_image() { convert "$1" -colorspace Gray -threshold 50% "$2"; }

sharpen_image() { convert "$1" -sharpen 0x3 "$2"; }

contrast_stretch_image() { convert "$1" -contrast-stretch 5%x5% "$2"; }

zoom_image() { convert "$1" -gravity center -crop 90%x90%+0+0 +repage "$2"; }

run_alpr() {
    local image_file="$1"
    local output_file="$2"
    alpr -c us -n 1 "$image_file" -j > "$output_file" 2>/dev/null
}

process_image() {
    local file_path="$1"

    log "Processing new image: $file_path"

    local base_name
    base_name=$(basename "$file_path")
    local tmp_json="${TMP_DIR}/${base_name}.json"

    run_alpr "$file_path" "$tmp_json"

    if jq -e '.results | length > 0' "$tmp_json" >/dev/null; then
        log "Plate found using transformation: original"
        jq --arg trans "original" '. + {transform_used: $trans}' "$tmp_json" > "${tmp_json}.tmp" && mv "${tmp_json}.tmp" "$tmp_json"
        rm -f "$file_path"
        publish_mqtt_file "$tmp_json"
        return
    fi

    transform_used=""
    transformations=(zoom_image invert_image grayscale_image threshold_image sharpen_image contrast_stretch_image)
    transform_names=("zoom" "inverted" "grayscale" "threshold" "sharpen" "contrast_stretch")

    declare -A pid_to_transform

    for i in "${!transformations[@]}"; do
        fallback_image="${TMP_DIR}/${base_name}_${transform_names[$i]}.jpg"
        log "Starting transformation: ${transform_names[$i]}"
        "${transformations[$i]}" "$file_path" "$fallback_image"
        run_alpr "$fallback_image" "${fallback_image}.json" &
        pid_to_transform[$!]="${transform_names[$i]}"
    done

    winning_json=""

    for pid in "${!pid_to_transform[@]}"; do
        if wait "$pid"; then
            transform_name="${pid_to_transform[$pid]}"
            fallback_json="${TMP_DIR}/${base_name}_${transform_name}.jpg.json"
            if [[ -f "$fallback_json" ]] && jq -e '.results | length > 0' "$fallback_json" >/dev/null; then
                transform_used="$transform_name"
                winning_json="$fallback_json"
                break
            fi
        fi
    done

    if [[ -n "$transform_used" ]]; then
        log "Plate found using transformation: $transform_used"
        jq --arg trans "$transform_used" '. + {transform_used: $trans}' "$winning_json" > "${winning_json}.tmp" && mv "${winning_json}.tmp" "$winning_json"
        rm -f "$file_path"
        publish_mqtt_file "$winning_json"
    else
        log "No plate found after all transformations, moving to trouble."
        mv "$file_path" "$TROUBLE_DIR/"
        publish_mqtt "{\"error\": \"no_plate_found\", \"file\": \"$base_name\"}"
        find "$TROUBLE_DIR" -type f -mmin +$((TROUBLE_MAX_AGE / 60)) -delete
    fi

    for name in "${transform_names[@]}"; do
        rm -f "${TMP_DIR}/${base_name}_${name}.jpg" "${TMP_DIR}/${base_name}_${name}.jpg.json"
    done
}

log "Watching directory: $WATCH_DIR"

iwatch -e default "$WATCH_DIR" 2>&1 | while IFS= read -r event; do
    file_path=$(echo "$event" | awk -F '\* ' '{print $2}' | awk -F ' is closed' '{print $1}')

    if [[ -z "$file_path" ]] || [[ ! -f "$file_path" ]]; then
        continue
    fi

    if ! echo "$file_path" | grep -iE '\.(jpg|jpeg)$' >/dev/null; then
        continue
    fi

    process_image "$file_path" &
done
