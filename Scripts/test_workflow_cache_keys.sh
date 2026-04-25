#!/bin/bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
workflow_file="${repo_root}/.github/workflows/CORE-ALL.yml"

assert_contains() {
	local pattern="$1"
	local message="$2"

	if ! grep -Fq -- "$pattern" "$workflow_file"; then
		echo "ASSERT FAILED: ${message}" >&2
		echo "Missing pattern: ${pattern}" >&2
		exit 1
	fi
}

assert_not_contains() {
	local pattern="$1"
	local message="$2"

	if grep -Fq -- "$pattern" "$workflow_file"; then
		echo "ASSERT FAILED: ${message}" >&2
		echo "Unexpected pattern: ${pattern}" >&2
		exit 1
	fi
}

assert_toolchain_has_no_restore_keys() {
	if awk '/Restore Toolchain Cache/,/Restore ccache Cache/' "$workflow_file" | grep -Fq -- 'restore-keys:'; then
		echo "ASSERT FAILED: toolchain cache should not restore older prefixes" >&2
		exit 1
	fi
}

assert_restore_ccache_uses_rolling_key() {
	local restore_block
	restore_block="$(awk '/Restore ccache Cache/,/Cache Diagnostics After Restore/' "$workflow_file")"

	if ! printf '%s\n' "$restore_block" | grep -Fq -- 'key: ccache-${{ runner.os }}-${{ env.DEVICE_SUBTARGET }}-${{ env.WRT_VER }}-${{ env.START_TIME }}'; then
		echo "ASSERT FAILED: restore ccache should use the rolling START_TIME key" >&2
		exit 1
	fi

	if printf '%s\n' "$restore_block" | grep -Eq -- '^[[:space:]]+key: ccache-\$\{\{ runner\.os \}\}-\$\{\{ env\.DEVICE_SUBTARGET \}\}-\$\{\{ env\.WRT_VER \}\}[[:space:]]*$'; then
		echo "ASSERT FAILED: restore ccache should no longer use the frozen stable key" >&2
		exit 1
	fi
}

assert_contains '- name: Restore Toolchain Cache' "workflow should restore toolchain cache explicitly"
assert_contains 'uses: actions/cache/restore@v5' "workflow should use cache restore actions"
assert_contains '- name: Save Toolchain Cache' "workflow should save toolchain cache explicitly"
assert_contains 'uses: actions/cache/save@v5' "workflow should use cache save actions"
assert_contains 'key: toolchain-${{ runner.os }}-${{ env.DEVICE_SUBTARGET }}-${{ env.WRT_VER }}-${{ env.REPO_GIT_hash_simple }}' "toolchain cache key should still include the source commit hash"
assert_toolchain_has_no_restore_keys

assert_contains '- name: Restore ccache Cache' "workflow should restore ccache explicitly"
assert_contains '- name: Save ccache Cache' "workflow should save ccache explicitly"
assert_contains 'key: ccache-${{ runner.os }}-${{ env.DEVICE_SUBTARGET }}-${{ env.WRT_VER }}-${{ env.START_TIME }}' "ccache restore and save keys should roll forward with the build start time"
assert_restore_ccache_uses_rolling_key
assert_contains 'restore-keys: |' "ccache restore step should still keep restore-keys"
assert_contains 'ccache-${{ runner.os }}-${{ env.DEVICE_SUBTARGET }}-${{ env.WRT_VER }}-' "ccache restore prefix should remain unchanged"
assert_not_contains "steps.restore_ccache_cache.outputs.cache-hit != 'true'" "ccache save should no longer be blocked on an exact cache hit"

assert_contains '- name: Cache Diagnostics After Restore' "workflow should log cache state after restore"
assert_contains '- name: Cache Diagnostics Before Save' "workflow should log cache state before save"
assert_contains '- name: Initialize Build Observability' "workflow should initialize build timing observability"
assert_contains 'echo "PREP_STAGE_START_TS=$(date +%s)" >> "$GITHUB_ENV"' "workflow should record the prep stage start timestamp"
assert_contains '- name: Report ccache Stats Before Build' "workflow should print ccache stats before compilation"
assert_contains '- name: Report ccache Stats After Build' "workflow should print ccache stats after compilation"
assert_contains 'CCACHE_DIR="${{ env.OPENWRT_PATH }}/.ccache" ccache -s | tee "$RUNNER_TEMP/ccache-before.txt" || true' "workflow should persist pre-build ccache stats for later summary"
assert_contains 'CCACHE_DIR="${{ env.OPENWRT_PATH }}/.ccache" ccache -s | tee "$RUNNER_TEMP/ccache-after.txt" || true' "workflow should persist post-build ccache stats for later summary"
assert_contains '- name: Write Build Metrics' "workflow should write structured build metrics for benchmark summary"
assert_contains '- name: Upload Build Metrics' "workflow should upload build metrics as an artifact"
assert_contains 'name: bench-metrics-' "workflow should upload metrics under a dedicated artifact prefix"
assert_contains "awk -F '[()%]'" "workflow should parse ccache hit rates with slash-safe field extraction"
assert_contains "awk -F '[:/()]'" "workflow should parse ccache cache sizes with slash-safe field extraction"
assert_not_contains 'sed -nE "s/${pattern}/\\1/p"' "workflow should not use slash-sensitive sed substitutions for metrics extraction"
assert_contains '【Lin】prep stage duration:' "workflow should log prep stage duration"
assert_contains '【Lin】download stage duration:' "workflow should log download stage duration"
assert_contains '【Lin】compile stage duration:' "workflow should log compile stage duration"
assert_not_contains '- name: Restore dl Cache' "workflow should not introduce dl cache in this change"
assert_not_contains '- name: Save dl Cache' "workflow should not introduce dl cache in this change"

echo "test_workflow_cache_keys: ok"
