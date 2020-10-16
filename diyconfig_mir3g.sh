#!/bin/bash
#=================================================
# Description: DIY script
# Lisence: MIT
#
#=================================================


package_root='package'

# 修改路由器名称
sed -i 's/OpenWrt/LinjwRouter/g' $package_root/base-files/files/bin/config_generate

# 修改IP
sed -i 's/192.168.1.1/192.168.31.1/g' $package_root/base-files/files/bin/config_generate
# sed -i 's/192.168.\$(/192.168.\$(/g' $package_root/base-files/files/bin/config_generate

# 修改wifi信息

# 修改wifi国家
sed -i 's/set wireless.radio\${devidx}.type=mac80211/set wireless.radio\${devidx}.type=mac80211 \n\t\t\t set wireless.radio\${devidx}.country=\"CN\"/g' $package_root/kernel/mac80211/files/lib/wifi/mac80211.sh
# 修改2.4G wifi信道
# sed -i 's/channel=\"11\"/channel=\"1\"/g' $package_root/kernel/mac80211/files/lib/wifi/mac80211.sh
# 修改5G wifi信道
# sed -i 's/channel=\"36\"/channel=\"153\"/g' $package_root/kernel/mac80211/files/lib/wifi/mac80211.sh
# 修改wifi名
sed -i 's/set wireless.default_radio\${devidx}.ssid=OpenWrt/set wireless.default_radio\${devidx}.ssid=ljwAP/g' $package_root/kernel/mac80211/files/lib/wifi/mac80211.sh
# 修改wifi密码
sed -i 's/set wireless.default_radio\${devidx}.encryption=none/set wireless.default_radio\${devidx}.encryption=psk-mixed \n\t\t\t set wireless.default_radio\${devidx}.key=12356789/g' $package_root/kernel/mac80211/files/lib/wifi/mac80211.sh




sed -i 's/set wireless.default_radio\${devidx}.ssid=OpenWrt/set wireless.default_radio\${devidx}.ssid=ljwAP/g' $package_root/kernel/mac80211/files/lib/wifi/mac80211.sh



# 修改闭源驱动ssid名，2G=ljwAP，5G=ljwAP_5G
# grep -rl '^SSID1=OpenWrt_5G' $package_root/lean/mt/drivers/mt_wifi/files/ | xargs sed -i 's/SSID1=OpenWrt/SSID1=ljwAP_5G/g'
grep -rl '^SSID1=OpenWrt' $package_root/lean/mt/drivers/mt_wifi/files/ | xargs sed -i 's/SSID1=OpenWrt/SSID1=ljwAP/g'
# sed -i 's/SSID1=OpenWrt/SSID1=ljwAP/g' $package_root/lean/mt/drivers/mt_wifi/files/mt7603.dat
# sed -i 's/SSID1=OpenWrt/SSID1=ljwAP/g' $package_root/lean/mt/drivers/mt_wifi/files/mt7615.2G.dat
# sed -i 's/SSID1=OpenWrt/SSID1=ljwAP/g' $package_root/lean/mt/drivers/mt_wifi/files/mt7615.5G.dat
# sed -i 's/SSID1=OpenWrt/SSID1=ljwAP/g' $package_root/lean/mt/drivers/mt_wifi/files/mt7615.dat
# sed -i 's/SSID1=OpenWrt/SSID1=ljwAP/g' $package_root/lean/mt/drivers/mt_wifi/files/mt7615.1.5G.dat
# sed -i 's/SSID1=OpenWrt/SSID1=ljwAP/g' $package_root/lean/mt/drivers/mt_wifi/files/mt7612.dat
# sed -i 's/SSID1=OpenWrt/SSID1=ljwAP/g' $package_root/lean/mt/drivers/mt_wifi/files/mt7615.1.2G.dat