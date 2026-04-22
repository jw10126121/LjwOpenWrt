#!/bin/bash

set -eu

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)

. "$SCRIPT_DIR/lib/source_flavor.sh"

selection=$(resolve_source_selection "")
printf '%s\n' "$selection" | grep -q '^REPO_URL=https://github.com/coolsnowwolf/lede$'
printf '%s\n' "$selection" | grep -q '^REPO_BRANCH=master$'
printf '%s\n' "$selection" | grep -q '^REPO_HASH=$'
printf '%s\n' "$selection" | grep -q '^SOURCE_FLAVOR=lean$'

selection=$(resolve_source_selection "abcdef123456")
printf '%s\n' "$selection" | grep -q '^REPO_URL=https://github.com/coolsnowwolf/lede$'
printf '%s\n' "$selection" | grep -q '^REPO_BRANCH=master$'
printf '%s\n' "$selection" | grep -q '^REPO_HASH=abcdef123456$'

echo "test_source_flavor: ok"
