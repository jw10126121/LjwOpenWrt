#!/bin/bash

set -eu

script_dir=${1:?script_dir is required}
base_script=${2:?base_script is required}
device_name=${3:?device_name is required}

if [ "$base_script" != 'auto' ]; then
	printf '%s\n' "$base_script"
	exit 0
fi

short_device_name=''
case "$device_name" in
	*-WIFI)
		short_device_name=${device_name%-WIFI}
		;;
	*-NOWIFI)
		short_device_name=${device_name%-NOWIFI}
		;;
esac

if [ -f "$script_dir/Packages-${device_name}.sh" ]; then
	printf '%s\n' "Packages-${device_name}.sh"
	exit 0
fi

if [ -n "$short_device_name" ] && [ -f "$script_dir/Packages-${short_device_name}.sh" ]; then
	printf '%s\n' "Packages-${short_device_name}.sh"
	exit 0
fi

printf '%s\n' 'Packages.sh'
