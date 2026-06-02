#!/bin/bash

# 说明：
# 1. 雅典娜 AX6600 专用包脚本，作为 Packages.sh 的设备专用入口。
# 2. 先执行通用 Packages.sh，再在本文件追加 AX6600 专用包逻辑。

set -eu

script_dir=$(cd "$(dirname "$0")" && pwd)

if [ "$(basename "$(pwd)")" != 'package' ]; then
	if [ -d "./package" ]; then
		cd ./package
	else
		echo "【Lin】请在 package 目录下执行，当前工作目录：$(pwd)"
		exit 0
	fi
fi

echo "【Lin】JD-AX6600 专用包脚本：先执行通用 Packages.sh"
bash "${script_dir}/Packages.sh"

echo "【Lin】JD-AX6600 专用包脚本：通用 Packages.sh 已执行，继续执行 AX6600 专用包逻辑"

# 在这里追加 AX6600 专用包逻辑。
# 注意：Packages.sh 是通过 bash 子进程执行的，里面定义的函数不会保留到当前脚本。
