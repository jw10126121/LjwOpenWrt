#!/bin/bash

set -eu

assert_contains() {
	local file_path=$1
	local pattern=$2
	local message=$3

	if ! grep -Fq "$pattern" "$file_path"; then
		echo "ASSERT FAILED: ${message}" >&2
		echo "Missing pattern: ${pattern}" >&2
		exit 1
	fi
}

assert_contains ".github/workflows/DEFAULT.yml" "default: 'IPQ60XX-NOWIFI-MINI'" "DEFAULT manual run should default to IPQ60XX-NOWIFI-MINI"
assert_contains ".github/workflows/main.yml" "default: 'IPQ60XX-NOWIFI-MINI'" "main manual run should default to IPQ60XX-NOWIFI-MINI"
assert_contains ".github/workflows/CACHE-BENCH.yml" "default: 'IPQ60XX-NOWIFI-MINI'" "CACHE-BENCH manual run should default to IPQ60XX-NOWIFI-MINI"

echo "test_workflow_default_device: ok"
