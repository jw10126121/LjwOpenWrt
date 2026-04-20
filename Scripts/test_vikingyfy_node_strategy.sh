#!/bin/bash

set -euo pipefail

packages_script="Scripts/Packages.sh"

assert_has_line() {
	local pattern="$1"
	local message="$2"

	if ! grep -Fxq "$pattern" "$packages_script"; then
		echo "ASSERT FAILED: ${message}" >&2
		echo "Missing pattern: ${pattern}" >&2
		exit 1
	fi
}

assert_lacks_line() {
	local pattern="$1"
	local message="$2"

	if grep -Fxq "$pattern" "$packages_script"; then
		echo "ASSERT FAILED: ${message}" >&2
		echo "Unexpected active line: ${pattern}" >&2
		exit 1
	fi
}

assert_has_line '    echo "【Lin】尝试使用 sbwml/feeds_packages_lang_node-prebuilt 加速 lang_node 编译"' "Packages.sh should use the same sbwml-only path for VIKINGYFY"
assert_has_line '    if LANG_NODE_PREBUILT_REPO="https://github.com/sbwml/feeds_packages_lang_node-prebuilt" \' "Packages.sh should wrap the sbwml helper in an if guard"
assert_has_line '    echo "【Lin】未命中可用的 sbwml lang_node 预编译分支，继续使用官方 lang/node"' "Packages.sh should fall back to official lang/node when sbwml cannot be used"
assert_lacks_line 'nxhack/openwrt-node-packages' "Packages.sh should not retain the nxhack node feed path"

echo "test_vikingyfy_node_strategy: ok"
