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

assert_contains ".github/workflows/DEFAULT.yml" "default: 'CMIOT-AX18-NOWIFI'" "DEFAULT manual run should default to CMIOT-AX18-NOWIFI"
assert_contains ".github/workflows/CACHE-BENCH.yml" "default: 'CMIOT-AX18-NOWIFI'" "CACHE-BENCH manual run should default to CMIOT-AX18-NOWIFI"

echo "test_workflow_default_device: ok"
