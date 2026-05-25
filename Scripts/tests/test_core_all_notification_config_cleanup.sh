#!/bin/bash

set -eu

workflow=".github/workflows/CORE-ALL.yml"

assert_not_contains() {
	local pattern="$1"
	local message="$2"

	if grep -Fq "$pattern" "$workflow"; then
		echo "ASSERT FAILED: ${message}" >&2
		echo "Unexpected pattern: ${pattern}" >&2
		exit 1
	fi
}

assert_contains() {
	local pattern="$1"
	local message="$2"

	if ! grep -Fq "$pattern" "$workflow"; then
		echo "ASSERT FAILED: ${message}" >&2
		echo "Missing pattern: ${pattern}" >&2
		exit 1
	fi
}

assert_not_contains 'Upload Config (上传配置文件)' 'CORE-ALL should no longer upload config artifacts before compile'
assert_not_contains 'system_content_note' 'CORE-ALL should no longer persist pre-compile notification snapshots'
assert_not_contains 'readme_desc_file=$OPENWRT_PATH/config_mine/readme.txt' 'CORE-ALL should no longer prepare pre-compile readme snapshot paths'
assert_contains 'Create Notification Content (创建推送结果内容)' 'CORE-ALL should still generate final notification content'
assert_contains 'ci_create_start_notification.sh' 'CORE-ALL should generate start notifications from the dedicated script'
assert_not_contains '${{ env.system_content }}' 'CORE-ALL start notification should no longer send raw system_content directly'

echo "test_core_all_notification_config_cleanup: ok"
