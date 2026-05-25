#!/bin/bash
# 说明：
# 1. 在 GitHub Actions 中生成编译开始阶段的多行通知内容。
# 2. 优先复用已生成的正文文件；否则基于当前 .config 动态生成一份带插件列表的说明。

set -euo pipefail

: "${GITHUB_ENV:?GITHUB_ENV is required}"
: "${GITHUB_OUTPUT:?GITHUB_OUTPUT is required}"

get_start_notify_body() {
    if [ -n "${start_notify_desc_file:-}" ] && [ -f "${start_notify_desc_file}" ]; then
        cat "${start_notify_desc_file}"
        return 0
    fi

    local scripts_dir=""
    local readme_script=""
    local tmp_desc_file=""

    scripts_dir="${GITHUB_WORKSPACE:?GITHUB_WORKSPACE is required}/${WRT_DIR_SCRIPTS:?WRT_DIR_SCRIPTS is required}"
    readme_script="${scripts_dir}/readme.sh"
    tmp_desc_file="$(mktemp "${TMPDIR:-/tmp}/start-notify.XXXXXX.txt")"

    bash "${readme_script}" \
        -c "${OPENWRT_PATH:?OPENWRT_PATH is required}/.config" \
        -o "${tmp_desc_file}" \
        -s "${system_content:-}" \
        -a "${WRT_MINE_SAY:-}" \
        -r 'false'

    cat "${tmp_desc_file}"
    rm -f "${tmp_desc_file}"
}

write_start_notify_content() {
    local target_file="$1"
    local notify_body=""

    notify_body="$(get_start_notify_body)"

    {
        echo "start_notify_content<<EOF"
        printf '%s\n' "${notify_body}"
        echo "EOF"
    } >> "${target_file}"
}

write_start_notify_content "${GITHUB_ENV}"
write_start_notify_content "${GITHUB_OUTPUT}"
