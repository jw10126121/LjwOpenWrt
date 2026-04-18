#!/bin/bash
# Create multiline notification content for GitHub env/output files.

set -euo pipefail

: "${GITHUB_ENV:?GITHUB_ENV is required}"
: "${GITHUB_OUTPUT:?GITHUB_OUTPUT is required}"

release_tag="${START_TIME:?START_TIME is required}_${DEVICE_SUBTARGET:?DEVICE_SUBTARGET is required}"
artifact_url="https://github.com/${GITHUB_REPOSITORY:?GITHUB_REPOSITORY is required}/actions/runs/${GITHUB_RUN_ID:?GITHUB_RUN_ID is required}"

write_notify_content() {
    local target_file="$1"
    {
        echo "notify_content<<EOF"
        if [ "${WRT_RELEASE_FIRMWARE:-false}" = "true" ]; then
            echo "Release下载地址：https://github.com/${GITHUB_REPOSITORY}/releases/tag/${release_tag}"
        fi
        echo "Artifact下载地址：${artifact_url}"
        echo ""
        printf '%s\n' "${system_content:-}"
        echo ""
        echo "编译状态：${COMPILE_STATUS:-unknown}"
        echo "编译开始：${START_TIME}"
        echo "编译结束：${END_TIME:-}"
        echo "EOF"
    } >> "${target_file}"
}

write_notify_content "${GITHUB_ENV}"
write_notify_content "${GITHUB_OUTPUT}"
