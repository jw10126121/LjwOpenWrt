#!/bin/bash

set -eu

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)

. "$SCRIPT_DIR/lib/source_flavor.sh"

[ "$(resolve_source_flavor "")" = "lean" ]
[ "$(resolve_source_flavor "https://github.com/coolsnowwolf/lede")" = "lean" ]
[ "$(resolve_source_flavor "https://github.com/VIKINGYFY/immortalwrt")" = "VIKINGYFY" ]
[ "$(resolve_source_flavor "https://github.com/openwrt/openwrt")" = "generic" ]

[ "$(resolve_source_default_branch "")" = "master" ]
[ "$(resolve_source_default_branch "https://github.com/coolsnowwolf/lede")" = "master" ]
[ "$(resolve_source_default_branch "https://github.com/VIKINGYFY/immortalwrt")" = "main" ]
[ "$(resolve_source_default_branch "https://github.com/openwrt/openwrt")" = "main" ]

[ "$(resolve_source_branch "" "")" = "master" ]
[ "$(resolve_source_branch "https://github.com/coolsnowwolf/lede" "")" = "master" ]
[ "$(resolve_source_branch "https://github.com/VIKINGYFY/immortalwrt" "")" = "main" ]
[ "$(resolve_source_branch "https://github.com/VIKINGYFY/immortalwrt" "dev")" = "dev" ]

selection=$(resolve_source_selection "" "" "")
printf '%s\n' "$selection" | grep -q '^REPO_URL=https://github.com/coolsnowwolf/lede$'
printf '%s\n' "$selection" | grep -q '^REPO_BRANCH=master$'
printf '%s\n' "$selection" | grep -q '^REPO_HASH=$'
printf '%s\n' "$selection" | grep -q '^SOURCE_FLAVOR=lean$'

selection=$(resolve_source_selection "https://github.com/VIKINGYFY/immortalwrt" "" "")
printf '%s\n' "$selection" | grep -q '^REPO_URL=https://github.com/VIKINGYFY/immortalwrt$'
printf '%s\n' "$selection" | grep -q '^REPO_BRANCH=main$'
printf '%s\n' "$selection" | grep -q '^SOURCE_FLAVOR=VIKINGYFY$'

selection=$(resolve_source_selection "https://github.com/coolsnowwolf/lede" "" "abcdef123456")
printf '%s\n' "$selection" | grep -q '^REPO_URL=https://github.com/coolsnowwolf/lede$'
printf '%s\n' "$selection" | grep -q '^REPO_BRANCH=master$'
printf '%s\n' "$selection" | grep -q '^REPO_HASH=abcdef123456$'

selection=$(resolve_source_selection "" "" "1234567890|https://github.com/VIKINGYFY/immortalwrt|")
printf '%s\n' "$selection" | grep -q '^REPO_URL=https://github.com/VIKINGYFY/immortalwrt$'
printf '%s\n' "$selection" | grep -q '^REPO_BRANCH=main$'
printf '%s\n' "$selection" | grep -q '^REPO_HASH=1234567890$'
printf '%s\n' "$selection" | grep -q '^SOURCE_FLAVOR=VIKINGYFY$'

selection=$(resolve_source_selection "https://github.com/coolsnowwolf/lede" "" "99887766||feature")
printf '%s\n' "$selection" | grep -q '^REPO_URL=https://github.com/coolsnowwolf/lede$'
printf '%s\n' "$selection" | grep -q '^REPO_BRANCH=feature$'
printf '%s\n' "$selection" | grep -q '^REPO_HASH=99887766$'

echo "test_source_flavor: ok"
