#!/bin/bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
workflow_file="${repo_root}/.github/workflows/CORE-ALL.yml"

assert_contains() {
	local pattern="$1"
	local message="$2"

	if ! grep -Fq "$pattern" "$workflow_file"; then
		echo "ASSERT FAILED: ${message}" >&2
		echo "Missing pattern: ${pattern}" >&2
		exit 1
	fi
}

assert_not_contains() {
	local pattern="$1"
	local message="$2"

	if grep -Fq "$pattern" "$workflow_file"; then
		echo "ASSERT FAILED: ${message}" >&2
		echo "Unexpected pattern: ${pattern}" >&2
		exit 1
	fi
}

assert_toolchain_has_no_restore_keys() {
	if awk '/Check Toolchain Cache/,/Check ccache Cache/' "$workflow_file" | grep -Fq 'restore-keys:'; then
		echo "ASSERT FAILED: toolchain cache should not restore older prefixes" >&2
		exit 1
	fi
}

assert_contains 'key: toolchain-${{ runner.os }}-${{ env.DEVICE_SUBTARGET }}-${{ env.WRT_VER }}-${{ env.REPO_GIT_hash_simple }}' "toolchain cache key should include the source commit hash"
assert_not_contains 'key: toolchain-${{ runner.os }}-${{ env.DEVICE_SUBTARGET }}-${{ env.WRT_VER }}-${{ hashFiles(' "toolchain cache should not rely on broad hashFiles invalidation anymore"
assert_toolchain_has_no_restore_keys
assert_contains 'key: ccache-${{ runner.os }}-${{ env.DEVICE_SUBTARGET }}-${{ env.WRT_VER }}' "ccache key should no longer include commit hash"
assert_not_contains 'key: ccache-${{ runner.os }}-${{ env.DEVICE_SUBTARGET }}-${{ env.WRT_VER }}-${{ env.REPO_GIT_hash_simple }}' "ccache key should not include commit hash"
assert_not_contains 'gh cache delete' "workflow should not delete ccache entries on cache miss"

echo "test_workflow_cache_keys: ok"
