#!/bin/bash
# 说明：
# 编译后从 manifest 文件中读取包版本号，补充到 upload/ 下的 readme/config 文件中。
# readme.sh 在编译前运行，部分包的版本号可能缺失；manifest 包含实际编译的版本信息。

set -euo pipefail

openwrt_path="${OPENWRT_PATH:?OPENWRT_PATH is required}"
upload_dir="${openwrt_path}/upload"

# 找到 manifest 文件（通常只有一个）
manifest_file=$(find "${upload_dir}" -maxdepth 1 -type f -iname "*manifest*" | head -n1)
if [ -z "${manifest_file}" ]; then
    echo "【Lin】未找到 manifest 文件，跳过版本补充"
    exit 0
fi

echo "【Lin】读取 manifest: ${manifest_file}"

manifest_count=$(awk -F ' - ' 'NF >= 2 && $1 != "" { count++ } END { print count + 0 }' "${manifest_file}")
echo "【Lin】manifest 中共 ${manifest_count} 个包"

# 扫描 artifact readme/config、通知 readme 和 release notes，补充缺失版本号。
supplemented=0
for target_file in \
    "${upload_dir}"/readme_*.txt \
    "${upload_dir}"/config_*.txt \
    "${openwrt_path}/config_mine/readme.txt" \
    "${openwrt_path}/readme_release.txt"; do
    [ -f "${target_file}" ] || continue

    tmp_file=$(mktemp)
    count_file=$(mktemp)
    awk -F ' - ' -v count_file="${count_file}" '
        FNR == NR {
            if (NF >= 2 && $1 != "") {
                name = $1
                version = $0
                sub(/^[^[:space:]][^ ]* - /, "", version)
                versions[name] = version
            }
            next
        }

        function trim(value) {
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
            return value
        }

        {
            line = $0
            content = line
            suffix = ""
            if (content ~ /<br>$/) {
                suffix = "<br>"
                sub(/<br>$/, "", content)
            }

            key = trim(content)
            if (line == "" ||
                line ~ /^#{1,4} / ||
                line ~ /^---/ ||
                line ~ /^</ ||
                content ~ / \(/ ||
                line ~ /编译说明|其他说明|集成的|安装包|支持目标|配置组织|Overlay|固件默认|下载与源码|刷机说明/) {
                print line
                next
            }

            if (key in versions) {
                print content " (" versions[key] ")" suffix
                supplemented++
            } else {
                print line
            }
        }

        END {
            print supplemented + 0 > count_file
        }
    ' "${manifest_file}" "${target_file}" > "${tmp_file}"

    mv -f "${tmp_file}" "${target_file}"
    file_supplemented=$(cat "${count_file}")
    rm -f "${count_file}"
    supplemented=$((supplemented + file_supplemented))
done

echo "【Lin】从 manifest 补充了 ${supplemented} 个包的版本号"
