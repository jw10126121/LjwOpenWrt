#!/bin/bash

set -eu

SCRIPT_DIR=$(cd "$(dirname "$0")/.." && pwd)
REPO_ROOT=$(cd "$(dirname "$0")/../.." && pwd)
CONFIG_DIR="$REPO_ROOT/Config"

extract_kv() {
    local line=$1
    local no_comment trimmed key value

    no_comment="${line%%#*}"
    trimmed=$(printf '%s' "$no_comment" | sed 's/[[:space:]]*$//')

    case "$trimmed" in
        CONFIG_*=*)
            key=${trimmed%%=*}
            value=${trimmed#*=}
            printf '%s=%s\n' "$key" "$value"
            ;;
    esac
}

check_config_file() {
    local target_config=$1
    shift
    local file line kv key value line_no=0
    local found_duplicate=0
    local base_values_file

    base_values_file=$(mktemp)

    for file in "$@"; do
        while IFS= read -r line; do
            kv=$(extract_kv "$line" || true)
            [ -n "$kv" ] || continue
            printf '%s\n' "$kv" >> "$base_values_file"
        done < "$file"
    done

    while IFS= read -r line; do
        line_no=$((line_no + 1))
        kv=$(extract_kv "$line" || true)
        [ -n "$kv" ] || continue
        key=${kv%%=*}
        value=${kv#*=}
        base_value=$(grep -E "^${key}=" "$base_values_file" | tail -n 1 | cut -d '=' -f 2- || true)
        if [ -n "$base_value" ] && [ "$base_value" = "$value" ]; then
            echo "$target_config:$line_no:$key=$value"
            found_duplicate=1
        fi
    done < "$target_config"

    rm -f "$base_values_file"

    return "$found_duplicate"
}

has_duplicate=0

check_config_file \
    "$CONFIG_DIR/IPQ60XX-NOWIFI-FW3.txt" \
    "$CONFIG_DIR/GENERAL.txt" || has_duplicate=1

check_config_file \
    "$CONFIG_DIR/MT6000-WIFI-FW3.txt" \
    "$CONFIG_DIR/GENERAL.txt" || has_duplicate=1

check_config_file \
    "$CONFIG_DIR/IPQ60XX-NOWIFI-MINI.txt" \
    "$CONFIG_DIR/GENERAL.txt" \
    "$CONFIG_DIR/GENERAL-SERVICE.txt" \
    "$CONFIG_DIR/variants/MINI-SERVICE.txt" || has_duplicate=1

check_config_file \
    "$CONFIG_DIR/MT6000-WIFI-MINI-FW3.txt" \
    "$CONFIG_DIR/GENERAL.txt" || has_duplicate=1

check_config_file \
    "$CONFIG_DIR/device-overlays/IPQ60XX-NOWIFI-MINI-FW3.txt" \
    "$CONFIG_DIR/GENERAL.txt" \
    "$CONFIG_DIR/GENERAL-SERVICE.txt" \
    "$CONFIG_DIR/GENERAL-FW3.txt" \
    "$CONFIG_DIR/variants/MINI-SERVICE.txt" \
    "$CONFIG_DIR/IPQ60XX-NOWIFI-MINI.txt" || has_duplicate=1

check_config_file \
    "$CONFIG_DIR/device-overlays/IPQ60XX-NOWIFI-MINI-FW4.txt" \
    "$CONFIG_DIR/GENERAL.txt" \
    "$CONFIG_DIR/GENERAL-SERVICE.txt" \
    "$CONFIG_DIR/GENERAL-FW4.txt" \
    "$CONFIG_DIR/variants/MINI-SERVICE.txt" \
    "$CONFIG_DIR/variants/MINI-FW4.txt" \
    "$CONFIG_DIR/IPQ60XX-NOWIFI-MINI.txt" || has_duplicate=1

if [ "$has_duplicate" -ne 0 ]; then
    echo "发现设备层或设备叠加层与其下层基础配置重复的同值配置，请继续收敛。" >&2
    exit 1
fi

echo "test_device_config_dedup: ok"
