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

assert_not_contains() {
	local pattern="$1"
	local message="$2"

	if grep -Fq "$pattern" "$packages_script"; then
		echo "ASSERT FAILED: ${message}" >&2
		echo "Unexpected pattern: ${pattern}" >&2
		exit 1
	fi
}

assert_contains 'UPDATE_PACKAGE "node" "nxhack/openwrt-node-packages" "openwrt-25.12" "pkg"' "VIKINGYFY should replace node with nxhack openwrt-25.12 feed"
assert_contains 'VIKINGYFY 源码风味直接使用 nxhack/openwrt-node-packages 的 node 包，跳过 lang_node 预编译替换' "Packages.sh should explain why lang_node prebuilt is skipped for VIKINGYFY"
assert_contains 'if [ "${source_flavor}" = "VIKINGYFY" ]; then' "Packages.sh should special-case VIKINGYFY in lang_node fix"
assert_not_contains 'local lang_node_prebuilt_repo="https://github.com/jw10126121/feeds_packages_lang_node-prebuilt"' "Packages.sh should not hardcode the old lang_node prebuilt repo strategy anymore"

echo "test_vikingyfy_node_strategy: ok"
