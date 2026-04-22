#!/bin/bash

resolve_source_flavor() {
    printf '%s\n' 'lean'
}

resolve_source_repo_url() {
    printf '%s\n' 'https://github.com/coolsnowwolf/lede'
}

resolve_source_default_branch() {
    printf '%s\n' 'master'
}

resolve_source_selection() {
    local source_hash_info="${2:-}"
    local source_flavor='lean'
    local repo_url=''
    local repo_branch=''
    local repo_hash=''
    local legacy_hash=''

    repo_url=$(resolve_source_repo_url)
    repo_branch=$(resolve_source_default_branch)

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
