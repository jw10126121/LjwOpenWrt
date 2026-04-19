#!/bin/bash

set -eu

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)

. "$SCRIPT_DIR/lib/source_flavor.sh"

[ "$(resolve_source_flavor "")" = "lean" ]
[ "$(resolve_source_flavor "lean")" = "lean" ]
[ "$(resolve_source_flavor "VIKINGYFY")" = "VIKINGYFY" ]

[ "$(resolve_source_repo_url "lean")" = "https://github.com/coolsnowwolf/lede" ]
[ "$(resolve_source_repo_url "VIKINGYFY")" = "https://github.com/VIKINGYFY/immortalwrt" ]

[ "$(resolve_source_default_branch "lean")" = "master" ]
[ "$(resolve_source_default_branch "VIKINGYFY")" = "main" ]

selection=$(resolve_source_selection "lean" "")
printf '%s\n' "$selection" | grep -q '^REPO_URL=https://github.com/coolsnowwolf/lede$'
printf '%s\n' "$selection" | grep -q '^REPO_BRANCH=master$'
printf '%s\n' "$selection" | grep -q '^REPO_HASH=$'
printf '%s\n' "$selection" | grep -q '^SOURCE_FLAVOR=lean$'

selection=$(resolve_source_selection "VIKINGYFY" "")
printf '%s\n' "$selection" | grep -q '^REPO_URL=https://github.com/VIKINGYFY/immortalwrt$'
printf '%s\n' "$selection" | grep -q '^REPO_BRANCH=main$'
printf '%s\n' "$selection" | grep -q '^SOURCE_FLAVOR=VIKINGYFY$'

selection=$(resolve_source_selection "lean" "abcdef123456")
printf '%s\n' "$selection" | grep -q '^REPO_URL=https://github.com/coolsnowwolf/lede$'
printf '%s\n' "$selection" | grep -q '^REPO_BRANCH=master$'
printf '%s\n' "$selection" | grep -q '^REPO_HASH=abcdef123456$'

echo "test_source_flavor: ok"
