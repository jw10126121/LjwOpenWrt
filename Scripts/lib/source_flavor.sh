#!/bin/bash

resolve_source_flavor() {
    local source_input="${1:-}"
    local source_input_lc

    source_input_lc=$(printf '%s' "$source_input" | tr '[:upper:]' '[:lower:]')

    if [ -z "${source_input_lc}" ]; then
        printf '%s\n' 'lean'
        return 0
    fi

    case "$source_input_lc" in
        lean|*coolsnowwolf/lede*)
            printf '%s\n' 'lean'
            ;;
        vikingyfy|immortalwrt|*vikingyfy/immortalwrt*)
            printf '%s\n' 'VIKINGYFY'
            ;;
        *)
            printf '%s\n' 'generic'
            ;;
    esac
}

resolve_source_repo_url() {
    local source_flavor

    source_flavor=$(resolve_source_flavor "${1:-}")

    case "${source_flavor}" in
        VIKINGYFY)
            printf '%s\n' 'https://github.com/VIKINGYFY/immortalwrt'
            ;;
        generic)
            printf '%s\n' 'https://github.com/openwrt/openwrt'
            ;;
        *)
            printf '%s\n' 'https://github.com/coolsnowwolf/lede'
            ;;
    esac
}

resolve_source_default_branch() {
    local source_flavor

    source_flavor=$(resolve_source_flavor "${1:-}")

    case "${source_flavor}" in
        VIKINGYFY|generic)
            printf '%s\n' 'main'
            ;;
        *)
            printf '%s\n' 'master'
            ;;
    esac
}

resolve_source_selection() {
    local input_source_flavor="${1:-}"
    local source_hash_info="${2:-}"
    local source_flavor=''
    local repo_url=''
    local repo_branch=''
    local repo_hash=''
    local legacy_hash=''

    source_flavor=$(resolve_source_flavor "${input_source_flavor}")
    repo_url=$(resolve_source_repo_url "${source_flavor}")
    repo_branch=$(resolve_source_default_branch "${source_flavor}")

    if [ -n "${source_hash_info}" ]; then
        if [[ "${source_hash_info}" == *"|"* ]]; then
            IFS='|' read -r legacy_hash _ <<EOF
${source_hash_info}
EOF
            repo_hash="${legacy_hash}"
        else
            repo_hash="${source_hash_info}"
        fi
    fi

    cat <<EOF
REPO_URL=${repo_url}
REPO_BRANCH=${repo_branch}
REPO_HASH=${repo_hash}
SOURCE_FLAVOR=${source_flavor}
EOF
}
