#!/bin/bash

# 将匹配的行复制到output.txt文件中
grep '^CONFIG_PACKAGE_luci-app-.*[=][ym]$' ax18.txt > ax18_full.txt

echo '  ' >> ax18_full.txt

grep '^CONFIG_PACKAGE_luci-i18n-.*[=][ym]$' ax18.txt >> ax18_full.txt

grep '^CONFIG_PACKAGE_ipv6helper.*[=][ym]$' ax18.txt >> ax18_full.txt

