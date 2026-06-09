#!/bin/bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
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

assert_toolchain_uses_scoped_restore_key() {
	local restore_block
	restore_block="$(awk '/Restore Toolchain Cache/,/Restore ccache Cache/' "$workflow_file")"

	if ! printf '%s\n' "$restore_block" | grep -Fq -- 'key: toolchain-${{ runner.os }}-${{ env.DEVICE_SUBTARGET }}-${{ env.WRT_VER }}-${{ env.REPO_GIT_hash_simple }}'; then
		echo "ASSERT FAILED: toolchain restore should use the shared subtarget/source key" >&2
		exit 1
	fi

	if printf '%s\n' "$restore_block" | grep -Fq -- 'WRT_CONFIG_LABEL'; then
		echo "ASSERT FAILED: toolchain restore should not split caches by config label" >&2
		exit 1
	fi

	if ! printf '%s\n' "$restore_block" | grep -Fq -- 'restore-keys: |'; then
		echo "ASSERT FAILED: toolchain restore should use restore-keys for broader reuse" >&2
		exit 1
	fi

	if ! printf '%s\n' "$restore_block" | grep -Fxq -- '          toolchain-${{ runner.os }}-${{ env.DEVICE_SUBTARGET }}-${{ env.WRT_VER }}-${{ env.REPO_GIT_hash_simple }}-'; then
		echo "ASSERT FAILED: toolchain restore prefix should keep the shared subtarget/source scope" >&2
		exit 1
	fi

	if ! printf '%s\n' "$restore_block" | grep -Fxq -- '          toolchain-${{ runner.os }}-${{ env.DEVICE_SUBTARGET }}-${{ env.WRT_VER }}-'; then
		echo "ASSERT FAILED: toolchain restore should fall back to the shared subtarget/version scope" >&2
		exit 1
	fi
}

assert_restore_ccache_uses_rolling_key() {
	local restore_block
	restore_block="$(awk '/Restore ccache Cache/,/Refresh Cache Metadata/' "$workflow_file")"

	if ! printf '%s\n' "$restore_block" | grep -Fq -- 'key: ccache-${{ runner.os }}-${{ env.DEVICE_SUBTARGET }}-${{ env.WRT_VER }}-${{ env.REPO_GIT_hash_simple }}-${{ env.START_DATE }}'; then
		echo "ASSERT FAILED: restore ccache should use the source-scoped daily rolling key" >&2
		exit 1
	fi

	if printf '%s\n' "$restore_block" | grep -Eq -- '^[[:space:]]+key: ccache-\$\{\{ runner\.os \}\}-\$\{\{ env\.DEVICE_SUBTARGET \}\}-\$\{\{ env\.WRT_VER \}\}-\$\{\{ env\.REPO_GIT_hash_simple \}\}[[:space:]]*$'; then
		echo "ASSERT FAILED: restore ccache should no longer use the frozen source hash key" >&2
		exit 1
	fi
}

assert_contains '- name: Restore Toolchain Cache' "workflow should restore toolchain cache explicitly"
assert_contains 'uses: actions/cache/restore@v5' "workflow should use cache restore actions"
assert_contains '- name: Save Toolchain Cache' "workflow should save toolchain cache explicitly"
assert_contains 'uses: actions/cache/save@v5' "workflow should use cache save actions"
assert_not_contains 'WRT_OVERLAYS_HASH' "workflow should not keep an unused overlays hash variable"
assert_contains 'key: toolchain-${{ runner.os }}-${{ env.DEVICE_SUBTARGET }}-${{ env.WRT_VER }}-${{ env.REPO_GIT_hash_simple }}' "toolchain cache key should be shared by subtarget and source hash"
assert_not_contains 'toolchain-${{ runner.os }}-${{ env.DEVICE_SUBTARGET }}-${{ env.WRT_VER }}-${{ env.REPO_GIT_hash_simple }}-${{ env.WRT_CONFIG_LABEL }}' "toolchain cache should not create one cache per device config"
assert_toolchain_uses_scoped_restore_key

assert_contains '- name: Restore ccache Cache' "workflow should restore ccache explicitly"
assert_contains '- name: Save ccache Cache' "workflow should save ccache explicitly"
assert_contains 'key: ccache-${{ runner.os }}-${{ env.DEVICE_SUBTARGET }}-${{ env.WRT_VER }}-${{ env.REPO_GIT_hash_simple }}-${{ env.START_DATE }}' "ccache restore and save keys should roll forward daily within the source scope"
assert_restore_ccache_uses_rolling_key
assert_contains 'restore-keys: |' "ccache restore step should still keep restore-keys"
assert_contains 'ccache-${{ runner.os }}-${{ env.DEVICE_SUBTARGET }}-${{ env.WRT_VER }}-${{ env.REPO_GIT_hash_simple }}-' "ccache source-scoped restore prefix should remain available"
assert_contains 'ccache-${{ runner.os }}-${{ env.DEVICE_SUBTARGET }}-${{ env.WRT_VER }}-' "ccache restore prefix should remain unchanged"
assert_not_contains "steps.restore_ccache_cache.outputs.cache-hit != 'true'" "ccache save should no longer be blocked on an exact cache hit"
assert_contains 'continue-on-error: true' "cache save steps should tolerate duplicate parallel cache reservations"

assert_contains '- name: Initialize Build Observability' "workflow should initialize build timing observability"
assert_contains 'echo "PREP_STAGE_START_TS=$(date +%s)" >> "$GITHUB_ENV"' "workflow should record the prep stage start timestamp"
assert_not_contains '- name: Evaluate Cache Restore State' "workflow should no longer classify cache restore state for benchmark reporting"
assert_not_contains '- name: Report ccache Stats Before Build' "workflow should no longer capture ccache stats before compilation"
assert_not_contains '- name: Report ccache Stats After Build' "workflow should no longer capture ccache stats after compilation"
assert_not_contains 'CCACHE_DIR="${{ env.OPENWRT_PATH }}/.ccache" ccache -s > "$RUNNER_TEMP/ccache-before.txt" || true' "workflow should no longer persist pre-build ccache stats"
assert_not_contains 'CCACHE_DIR="${{ env.OPENWRT_PATH }}/.ccache" ccache -s > "$RUNNER_TEMP/ccache-after.txt" || true' "workflow should no longer persist post-build ccache stats"
assert_not_contains '- name: Write Build Metrics' "workflow should no longer write benchmark metrics artifacts"
assert_not_contains '- name: Upload Build Metrics' "workflow should no longer upload benchmark metrics artifacts"
assert_not_contains 'name: bench-metrics-' "workflow should no longer upload benchmark metrics under a dedicated artifact prefix"
assert_not_contains "ccache_restore_state=\${{ steps.evaluate_cache_restore_state.outputs.ccache_restore_state || 'no-cache' }}" "workflow should no longer emit ccache restore state metrics"
assert_not_contains "awk -F '[()%]'" "workflow should no longer parse ccache hit rates for benchmark metrics"
assert_not_contains "awk -F '[:/()]'" "workflow should no longer parse ccache cache sizes for benchmark metrics"
assert_not_contains 'sed -nE "s/${pattern}/\\1/p"' "workflow should not use slash-sensitive sed substitutions for metrics extraction"
assert_not_contains '- name: Restore dl Cache' "workflow should not introduce dl cache in this change"
assert_not_contains '- name: Save dl Cache' "workflow should not introduce dl cache in this change"

echo "test_workflow_cache_keys: ok"
