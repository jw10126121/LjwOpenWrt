#!/bin/bash
# 说明：
# 1. 在 CI 末尾整理编译产物、README、配置文件和安装包归档。
# 2. 会调用 readme.sh 与 Organize_Packages.sh 生成最终上传目录。

set -euo pipefail

openwrt_path="${OPENWRT_PATH:?OPENWRT_PATH is required}"
scripts_dir="${GITHUB_WORKSPACE:?GITHUB_WORKSPACE is required}/${WRT_DIR_SCRIPTS:?WRT_DIR_SCRIPTS is required}"

cd "${openwrt_path}"
mkdir -p ./upload ./upload/packages ./upload/configs

rm -f ./config_mine/readme.txt
readme_script="${scripts_dir}/readme.sh"
[ -f "${readme_script}" ] && chmod +x "${readme_script}"

to_my_say_detail="${system_content:-}"

[ -f "${readme_script}" ] && bash "${readme_script}" -c "./.config" -o "./config_mine/readme.txt" -s "${to_my_say_detail}" -a "${WRT_MINE_SAY:-}" -r 'false'
[ -f "${readme_script}" ] && bash "${readme_script}" -c "./.config" -o "./readme_release.txt" -s "${to_my_say_detail}" -a "${WRT_MINE_SAY:-}" -r 'true'

readme_desc_file="${openwrt_path}/config_mine/readme.txt"
release_desc_file="${openwrt_path}/readme_release.txt"
echo "readme_desc_file=${readme_desc_file}" >> "${GITHUB_ENV}"
echo "release_desc_file=${release_desc_file}" >> "${GITHUB_ENV}"

build_name_prefix="${BUILD_VARIANT_TAG:?BUILD_VARIANT_TAG is required}_${DEVICE_SUBTARGET:?DEVICE_SUBTARGET is required}_${DEVICE_NAME_LIST_LIAN:?DEVICE_NAME_LIST_LIAN is required}_${WRT_VER:?WRT_VER is required}_${START_TIME:?START_TIME is required}"

cp -f ./my_config.txt "./upload/config_${build_name_prefix}.txt"
cp -f "${readme_desc_file}" "./upload/readme_${build_name_prefix}.txt"

tmp_dir="$(mktemp -d)"
# 先把分散在 bin/ 下的所有 ipk/apk 收拢到临时目录，再统一重组和压缩。
find ./bin/packages/ -type f \( -name "*.ipk" -o -name "*.apk" \) -exec mv -f {} "${tmp_dir}" \;
find ./bin/targets/ -type f \( -name "*.ipk" -o -name "*.apk" \) -exec mv -f {} "${tmp_dir}" \;
find ./bin/targets/ -iregex ".*\(buildinfo\|json\|manifest\|sha256sums\|packages\)$" -exec rm -rf {} +
find ./bin/targets/ -iregex ".*\(initramfs-uImage\).*" -exec rm -rf {} +
find ./bin/targets/ -iregex ".*\(-imagebuilder-\).*" -exec rm -rf {} +
bash "${scripts_dir}/Organize_Packages.sh" "${tmp_dir}" "./.config"
tar -zcf "./upload/Packages_${build_name_prefix}.tar.gz" -C "${tmp_dir}" --transform 's,^./,,' .
rm -rf "${tmp_dir}"
rm -rf ./upload/packages

# 固件镜像文件按“源码风味_FW_FRP_子平台_设备名_版本_开始时间”重命名，方便发布页辨认。
for type in ${DEVICE_NAME_LIST:-}; do
    while IFS= read -r file; do
        [ -z "${file}" ] && continue
        ext="$(basename "${file}" | cut -d '.' -f 2-)"
        name="$(basename "${file}" | cut -d '.' -f 1 | grep -io "\(${type}\).*")"
        new_file="${BUILD_VARIANT_TAG:?BUILD_VARIANT_TAG is required}_${DEVICE_SUBTARGET:?DEVICE_SUBTARGET is required}_${name}_${WRT_VER:?WRT_VER is required}_${START_TIME:?START_TIME is required}.${ext}"
        mv -f "${file}" "./upload/${new_file}"
    done < <(find ./bin/targets/ -type f -iname "*${type}*.*")
done

find ./bin/targets/ -type f -not -name '*openwrt-imagebuilder*' -exec mv -f {} ./upload/ \;
echo "status=success" >> "${GITHUB_OUTPUT}"
