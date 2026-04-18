#!/bin/bash
# Organize compiled files into the upload directory.

set -euo pipefail

openwrt_path="${OPENWRT_PATH:?OPENWRT_PATH is required}"
scripts_dir="${GITHUB_WORKSPACE:?GITHUB_WORKSPACE is required}/${WRT_DIR_SCRIPTS:?WRT_DIR_SCRIPTS is required}"

cd "${openwrt_path}"
mkdir -p ./upload ./upload/packages ./upload/configs

rm -f ./config_mine/readme.txt
readme_script="${scripts_dir}/readme.sh"
[ -f "${readme_script}" ] && chmod +x "${readme_script}"

to_my_say_detail=$(printf '%s\n编译开始：%s\n编译完成：%s\n' "${system_content:-}" "${START_TIME:?START_TIME is required}" "${END_TIME:?END_TIME is required}")

[ -f "${readme_script}" ] && bash "${readme_script}" -c "./.config" -o "./config_mine/readme.txt" -s "${to_my_say_detail}" -a "${WRT_MINE_SAY:-}" -r 'false'
[ -f "${readme_script}" ] && bash "${readme_script}" -c "./.config" -o "./readme_release.txt" -s "${to_my_say_detail}" -a "${WRT_MINE_SAY:-}" -r 'true'

readme_desc_file="${openwrt_path}/config_mine/readme.txt"
release_desc_file="${openwrt_path}/readme_release.txt"
echo "readme_desc_file=${readme_desc_file}" >> "${GITHUB_ENV}"
echo "release_desc_file=${release_desc_file}" >> "${GITHUB_ENV}"

cp -f ./my_config.txt ./upload/config.txt
cp -f "${readme_desc_file}" ./upload/readme.txt

tmp_dir="$(mktemp -d)"
generated_overrides="$(mktemp)"
find ./bin/packages/ -type f \( -name "*.ipk" -o -name "*.apk" \) -exec mv -f {} "${tmp_dir}" \;
find ./bin/targets/ -type f \( -name "*.ipk" -o -name "*.apk" \) -exec mv -f {} "${tmp_dir}" \;
find ./bin/targets/ -iregex ".*\(buildinfo\|json\|manifest\|sha256sums\|packages\)$" -exec rm -rf {} +
find ./bin/targets/ -iregex ".*\(initramfs-uImage\).*" -exec rm -rf {} +
find ./bin/targets/ -iregex ".*\(-imagebuilder-\).*" -exec rm -rf {} +
bash "${scripts_dir}/generate_package_overrides.sh" "${tmp_dir}" "./.config" "${generated_overrides}"
bash "${scripts_dir}/Organize_Packages.sh" "${tmp_dir}" "./.config" "${generated_overrides}"
tar -zcf ./upload/Packages.tar.gz -C "${tmp_dir}" --transform 's,^./,,' .
rm -f "${generated_overrides}"
rm -rf "${tmp_dir}"
rm -rf ./upload/packages

for type in ${DEVICE_NAME_LIST:-}; do
    while IFS= read -r file; do
        [ -z "${file}" ] && continue
        ext="$(basename "${file}" | cut -d '.' -f 2-)"
        name="$(basename "${file}" | cut -d '.' -f 1 | grep -io "\(${type}\).*")"
        new_file="${DEVICE_SUBTARGET:?DEVICE_SUBTARGET is required}_${name}_${WRT_VER:?WRT_VER is required}_${START_TIME:?START_TIME is required}.${ext}"
        mv -f "${file}" "./upload/${new_file}"
    done < <(find ./bin/targets/ -type f -iname "*${type}*.*")
done

find ./bin/targets/ -type f -not -name '*openwrt-imagebuilder*' -exec mv -f {} ./upload/ \;
echo "status=success" >> "${GITHUB_OUTPUT}"
