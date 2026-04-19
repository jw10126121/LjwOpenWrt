#!/bin/bash

set -euo pipefail

packages_script="Scripts/Packages.sh"

assert_contains() {
	local pattern="$1"
	local message="$2"

	if ! grep -Fq "$pattern" "$packages_script"; then
		echo "ASSERT FAILED: ${message}" >&2
		echo "Missing pattern: ${pattern}" >&2
		exit 1
	fi
}

assert_contains 'local use_nxhack_node_feed=false' "Packages.sh should define a dedicated nxhack node-feed switch"
assert_contains 'if [ "${source_flavor}" = "VIKINGYFY" ] || { [ "${source_flavor}" = "lean" ] && [ "${WRT_DEVICE:-}" = "IPQ60XX-NOWIFI" ] && [ "${WRT_FIREWALL:-}" = "fw3" ]; }; then' "Packages.sh should enable nxhack node feed for VIKINGYFY and lean IPQ60XX fw3 test target"
assert_contains 'UPDATE_PACKAGE "node" "nxhack/openwrt-node-packages" "openwrt-25.12" "pkg"' "Packages.sh should use nxhack openwrt-25.12 node feed"
assert_contains 'LEAN + IPQ60XX-NOWIFI + fw3 测试组合使用 nxhack/openwrt-node-packages 的 node 包' "Packages.sh should log the lean test-target override"
assert_contains '当前组合继续使用 jw10126121/feeds_packages_lang_node-prebuilt 的 lang_node 预编译替换' "Packages.sh should log when the legacy lang_node prebuilt strategy is used"

echo "test_nxhack_node_test_target: ok"
