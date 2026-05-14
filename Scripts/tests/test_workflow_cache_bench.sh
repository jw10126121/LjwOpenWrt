#!/bin/bash

set -euo pipefail

workflow_file=".github/workflows/CACHE-BENCH.yml"

assert_contains() {
	local pattern="$1"
	local message="$2"

	if ! grep -Fq -- "$pattern" "$workflow_file"; then
		echo "ASSERT FAILED: ${message}" >&2
		echo "Missing pattern: ${pattern}" >&2
		exit 1
	fi
}

assert_count() {
	local pattern="$1"
	local expected="$2"
	local message="$3"
	local actual

	actual=$(grep -Fc -- "$pattern" "$workflow_file")
	if [ "$actual" -ne "$expected" ]; then
		echo "ASSERT FAILED: ${message}" >&2
		echo "Expected count: ${expected}, actual: ${actual}, pattern: ${pattern}" >&2
		exit 1
	fi
}

assert_contains "workflow_dispatch:" "CACHE-BENCH should support manual runs"
assert_contains "BENCH_MODE:" "CACHE-BENCH should expose benchmark mode input"
assert_contains "warm-and-measure" "CACHE-BENCH should support full two-run benchmarking"
assert_contains "measure-only" "CACHE-BENCH should support running only the measured second pass"
assert_contains "warm_cache:" "CACHE-BENCH should define the warm-up job"
assert_contains "measure_after_warm:" "CACHE-BENCH should define the measured second run after warm-up"
assert_contains "measure_only:" "CACHE-BENCH should define the measured run for pre-warmed cache"
assert_contains "needs: warm_cache" "measure-after-warm run should wait for the warm-up run"
assert_count "uses: ./.github/workflows/DEFAULT.yml" 3 "CACHE-BENCH should call DEFAULT three times across both modes"
assert_contains "WHAT_MY_SAY: \${{ format('[cache-bench warm] {0}', inputs.WHAT_MY_SAY) }}" "warm run should be labeled in notifications"
assert_count "WHAT_MY_SAY: \${{ format('[cache-bench measure] {0}', inputs.WHAT_MY_SAY) }}" 2 "both measure modes should be labeled in notifications"
assert_count "WRT_SOURCE_HASH_INFO: ecec1ef93a8920f30ef927d989b13b674d614ca6" 3 "CACHE-BENCH should pin every benchmark run to the fixed source hash"
assert_contains "WRT_RELEASE_FIRMWARE:" "CACHE-BENCH should allow disabling release publishing"
assert_contains "default: false" "CACHE-BENCH should default firmware release off for benchmarks"
assert_not_contains() {
	local pattern="$1"
	local message="$2"

	if grep -Fq -- "$pattern" "$workflow_file"; then
		echo "ASSERT FAILED: ${message}" >&2
		echo "Unexpected pattern: ${pattern}" >&2
		exit 1
	fi
}

assert_not_contains "benchmark_summary:" "CACHE-BENCH should no longer include a summary job"
assert_not_contains 'echo "## Cache Benchmark"' "CACHE-BENCH should no longer render a metrics summary"
assert_not_contains "uses: actions/download-artifact@v5" "CACHE-BENCH should no longer download build metrics artifacts"
assert_not_contains "pattern: bench-metrics-*" "CACHE-BENCH should no longer filter benchmark metric artifacts"
assert_not_contains "merge-multiple: true" "CACHE-BENCH should no longer merge benchmark metric artifacts"
assert_not_contains 'echo "| Phase | Toolchain | ccache | Prep(s) | Download(s) | Compile(s) | Hit rate before | Hit rate after | Status |"' "CACHE-BENCH should no longer render a metrics table"
assert_not_contains 'printf "exact-hit"' "CACHE-BENCH should no longer format exact-hit summary labels"
assert_not_contains 'printf "fallback-hit"' "CACHE-BENCH should no longer format fallback-hit summary labels"
assert_not_contains 'printf "no-cache"' "CACHE-BENCH should no longer format no-cache summary labels"

echo "test_workflow_cache_bench: ok"
