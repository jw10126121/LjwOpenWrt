#!/bin/bash

# 说明：DEFAULT / CUSTOM 系列都应通过 run-name 提供更直观的运行显示名；
# workflow 固定 name 仍保持稳定。

set -eu

default_line=$(grep -n '^run-name:' .github/workflows/DEFAULT.yml | head -n 1 | cut -d: -f2- || true)
printf '%s\n' "$default_line" | grep -q 'inputs.WRT_DEVICE'
printf '%s\n' "$default_line" | grep -q 'inputs.WRT_FIREWALL'
printf '%s\n' "$default_line" | grep -q 'inputs.WRT_OVERLAYS'
grep -q 'WRT_LUCI_BRANCH:' .github/workflows/DEFAULT.yml

grep -q "^name: CUSTOM$" .github/workflows/CUSTOM.yml
grep -q "^run-name: CUSTOM-" .github/workflows/CUSTOM.yml
grep -q "^name: CUSTOM-APK$" .github/workflows/CUSTOM-APK.yml
grep -q "^run-name: CUSTOM-APK-static-apk$" .github/workflows/CUSTOM-APK.yml
grep -q "^name: CUSTOM-LUCI2305$" .github/workflows/CUSTOM-LUCI2305.yml
grep -q "^run-name: CUSTOM-LUCI2305-" .github/workflows/CUSTOM-LUCI2305.yml

echo "test_workflow_display_names: ok"
