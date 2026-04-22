#!/bin/bash

resolve_source_selection() {
    local repo_hash="${1:-}"

    cat <<EOF
REPO_URL=https://github.com/coolsnowwolf/lede
REPO_BRANCH=master
REPO_HASH=${repo_hash}
SOURCE_FLAVOR=lean
EOF
}
