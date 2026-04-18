#!/bin/sh
# 首次启动时把 ttyd 改成 root 免密登录，并开放到所有地址。
uci set ttyd.@ttyd[0].command='/bin/login -f root'
uci set ttyd.@ttyd[0].interface='0.0.0.0'
uci commit ttyd
/etc/init.d/ttyd restart

exit 0
