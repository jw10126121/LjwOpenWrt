#!/bin/bash
#=================================================
# Description: DIY script
# Lisence: MIT
#=================================================
#

from_file=$1
to_file=$2

#[[ -e $to_file ]] && rm -rf $to_file
sed -n '/^[ ]*[CONFIG_]/p' $from_file >> $to_file