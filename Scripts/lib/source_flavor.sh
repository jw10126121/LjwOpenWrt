#!/bin/bash

resolve_source_flavor() {
    local repo_url="${1:-}"
    local repo_url_lc

    repo_url_lc=$(printf '%s' "$repo_url" | tr '[:upper:]' '[:lower:]')

    if [ -z "${repo_url_lc}" ]; then
        printf '%s\n' 'lean'
        return 0
    fi

    case "$repo_url_lc" in
        *coolsnowwolf/lede*)
            printf '%s\n' 'lean'
            ;;
        *vikingyfy/immortalwrt*)
            printf '%s\n' 'VIKINGYFY'
            ;;
        *)
            printf '%s\n' 'generic'
            ;;
    esac
}

resolve_source_default_branch() {
    local repo_url="${1:-}"
    local source_flavor

    source_flavor=$(resolve_source_flavor "${repo_url}")

    case "${source_flavor}" in
        VIKINGYFY|generic)
            printf '%s\n' 'main'
            ;;
        *)
            printf '%s\n' 'master'
            ;;
    esac
}

resolve_source_branch() {
    local repo_url="${1:-}"
    local repo_branch="${2:-}"

    if [ -n "${repo_branch}" ]; then
        printf '%s\n' "${repo_branch}"
        return 0
    fi

    resolve_source_default_branch "${repo_url}"
}

resolve_source_selection() {
    local input_repo_url="${1:-}"
    local input_repo_branch="${2:-}"
    local source_hash_info="${3:-}"
    local repo_url="${input_repo_url:-https://github.com/coolsnowwolf/lede}"
    local repo_branch=''
    local repo_hash=''
    local legacy_hash=''
    local legacy_url=''
    local legacy_branch=''
    local source_flavor=''

    if [ -n "${source_hash_info}" ]; then
        if [[ "${source_hash_info}" == *"|"* ]]; then
            IFS='|' read -r legacy_hash legacy_url legacy_branch <<EOF
${source_hash_info}
EOF
            repo_hash="${legacy_hash}"
            [ -n "${legacy_url}" ] && repo_url="${legacy_url}"
            repo_branch=$(resolve_source_branch "${repo_url}" "${legacy_branch:-${input_repo_branch}}")
        else
            repo_hash="${source_hash_info}"
            repo_branch=$(resolve_source_branch "${repo_url}" "${input_repo_branch}")
        fi
    else
        repo_branch=$(resolve_source_branch "${repo_url}" "${input_repo_branch}")
    fi

    source_flavor=$(resolve_source_flavor "${repo_url}")

    cat <<EOF
REPO_URL=${repo_url}
REPO_BRANCH=${repo_branch}
REPO_HASH=${repo_hash}
SOURCE_FLAVOR=${source_flavor}
EOF
}
