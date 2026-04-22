#!/bin/bash

set -eu

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)

. "$SCRIPT_DIR/lib/source_flavor.sh"

[ "$(resolve_source_flavor "")" = "lean" ]
[ "$(resolve_source_flavor "lean")" = "lean" ]
[ "$(resolve_source_flavor "VIKINGYFY")" = "lean" ]
[ "$(resolve_source_flavor "generic")" = "lean" ]

[ "$(resolve_source_repo_url "lean")" = "https://github.com/coolsnowwolf/lede" ]
[ "$(resolve_source_repo_url "VIKINGYFY")" = "https://github.com/coolsnowwolf/lede" ]

[ "$(resolve_source_default_branch "lean")" = "master" ]
[ "$(resolve_source_default_branch "VIKINGYFY" "IPQ60XX-NOWIFI")" = "master" ]
[ "$(resolve_source_default_branch "generic" "MT6000-WIFI")" = "master" ]

selection=$(resolve_source_selection "lean" "" "IPQ60XX-NOWIFI")
printf '%s\n' "$selection" | grep -q '^REPO_URL=https://github.com/coolsnowwolf/lede$'
printf '%s\n' "$selection" | grep -q '^REPO_BRANCH=master$'
printf '%s\n' "$selection" | grep -q '^REPO_HASH=$'
printf '%s\n' "$selection" | grep -q '^SOURCE_FLAVOR=lean$'

selection=$(resolve_source_selection "VIKINGYFY" "" "IPQ60XX-NOWIFI")
printf '%s\n' "$selection" | grep -q '^REPO_URL=https://github.com/coolsnowwolf/lede$'
printf '%s\n' "$selection" | grep -q '^REPO_BRANCH=master$'
printf '%s\n' "$selection" | grep -q '^SOURCE_FLAVOR=lean$'

selection=$(resolve_source_selection "lean" "abcdef123456" "IPQ60XX-NOWIFI")
printf '%s\n' "$selection" | grep -q '^REPO_URL=https://github.com/coolsnowwolf/lede$'
printf '%s\n' "$selection" | grep -q '^REPO_BRANCH=master$'
printf '%s\n' "$selection" | grep -q '^REPO_HASH=abcdef123456$'

echo "test_source_flavor: ok"
