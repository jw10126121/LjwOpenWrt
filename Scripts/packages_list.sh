#!/bin/bash


ACTION_DIR=$1
PACKAGE_NAME=$2
PACKAGE_PRE_LIST=$3
echo "【LinInfo】操作目录：${ACTION_DIR}，整理${PACKAGE_NAME}的安装包"
PACKAGE_DIRNAME="$ACTION_DIR/$PACKAGE_NAME"
mkdir -p "$PACKAGE_DIRNAME"
for pkg in $PACKAGE_PRE_LIST; do
    for ext in ipk apk; do
        file=$(find "$ACTION_DIR" -name "${pkg}*.$ext" 2>/dev/null)
        if [ -n "$file" ]; then
            cp -r "$file" "$PACKAGE_DIRNAME"
            echo "【LinInfo】复制文件 $file 到： $PACKAGE_DIRNAME"
        fi
    done
done