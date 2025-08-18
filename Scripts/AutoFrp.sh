#!/bin/bash

# 该脚本，用于通过IPQ60XX-NOWIFI.txt生成IPQ60XX-NOWIFI_FRPS.txt

# 输入文件和输出文件
input_file="../Config/IPQ60XX-NOWIFI.txt"
output_file="../Config/IPQ60XX-NOWIFI_FRPS.txt"

# 检查输入文件是否存在
if [ ! -f "$input_file" ]; then
    echo "输入文件 $input_file 不存在！"
    exit 1
fi

# 清空或创建输出文件
> "$output_file"

# 逐行处理输入文件
while IFS= read -r line; do
    # 检查是否是需要反转值的配置项
    if [[ "$line" =~ ^(CONFIG_PACKAGE_frpc|CONFIG_PACKAGE_luci-app-frpc|CONFIG_PACKAGE_luci-i18n-frpc-zh-cn|CONFIG_PACKAGE_luci-app-frps|CONFIG_PACKAGE_luci-i18n-frps-zh-cn|CONFIG_PACKAGE_frps)= ]]; then
        # 反转值
        if [[ "$line" == *=y ]]; then
            echo "${line/=y/=m}" >> "$output_file"
        else
            echo "${line/=m/=y}" >> "$output_file"
        fi
    else
        # 其他配置项保持不变
        echo "$line" >> "$output_file"
    fi
done < "$input_file"

echo "生成文件 $output_file 完成！"