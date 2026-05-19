#!/bin/bash

set -eu

default_workflow=".github/workflows/DEFAULT.yml"
cache_bench_workflow=".github/workflows/CACHE-BENCH.yml"

assert_contains() {
	local file_path="$1"
	local pattern="$2"
	local message="$3"

	if ! grep -Fq "$pattern" "$file_path"; then
		echo "ASSERT FAILED: ${message}" >&2
		echo "Missing pattern: ${pattern}" >&2
		exit 1
	fi
}

for device in \
	CMIOT-AX18-NOWIFI \
	CMIOT-AX18-NOWIFI-MINI \
	IPQ60XX-NOWIFI \
	IPQ60XX-NOWIFI-MINI \
	JD-AX1800PRO-WIFI \
	JD-AX1800PRO-NOWIFI \
	JD-AX6600-WIFI \
	MT6000-WIFI \
	MT6000-WIFI-MINI \
	MIR3G-WIFI-MINI
do
	assert_contains "$default_workflow" "$device" "DEFAULT should expose ${device} in manual choices"
	assert_contains "$cache_bench_workflow" "$device" "CACHE-BENCH should expose ${device} in manual choices"
done

echo "test_workflow_manual_device_options: ok"
