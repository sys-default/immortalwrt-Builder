#!/bin/sh
# 99-custom 就是immortalwrt固件首次启动时运行的脚本 位于固件内的/etc/uci-defaults/99-custom
# Log file for debugging
LOGFILE="/tmp/log/uci-defaults-log"
echo "Starting 99-custom at $(date)" >>$LOGFILE

# lan_ip_address=""
#
# pppoe_username=""
# pppoe_password=""

# 1. 先获取所有物理接口列表
ifnames=""
for iface in /sys/class/net/*; do
    iface_name=$(basename "$iface")
    if [ -e "$iface/device" ] && echo "$iface_name" | grep -Eq '^eth|^en'; then
        ifnames="$ifnames $iface_name"
    fi
done
ifnames=$(echo "$ifnames" | awk '{$1=$1};1')

count=$(echo "$ifnames" | wc -w)
echo "Detected physical interfaces: $ifnames" >>$LOGFILE
echo "Interface count: $count" >>$LOGFILE

# 2. 根据板子型号映射WAN和LAN接口
board_name=$(cat /tmp/sysinfo/board_name 2>/dev/null || echo "unknown")
echo "Board detected: $board_name" >>$LOGFILE

# 3. 配置网络
if [ "$count" -eq 1 ]; then
    # 单网口设备，DHCP模式
    uci set network.lan.proto='dhcp'
    uci delete network.lan.ipaddr
    uci delete network.lan.netmask
    uci delete network.lan.gateway
    uci delete network.lan.dns
    uci commit network
elif [ "$count" -gt 1 ]; then
    # 默认第一个接口为WAN，其余为LAN
    if [ "$count" -eq 2 ]; then
        wan_ifname=$(echo "$ifnames" | awk '{print $1}')
        lan_ifname=$(echo "$ifnames" | awk '{print $2}')

        uci set network.wan.device="$wan_ifname"
        # 查找 br-lan 设备 section, 存在则删除
        section=$(uci show network | awk -F '[.=]' '/\.@?device\[[0-9]+\]\.name=.br-lan.$/ {print $2; exit}')
        if [ -z "$section" ]; then
            echo "error: cannot find device 'br-lan'." >>$LOGFILE
        else
            # 删除原有 br-lan 设备
            uci delete "network.$section"
        fi
        # 配置LAN口
        uci set network.lan.device="$lan_ifname"

    elif [ "$count" -gt 2 ]; then
        wan_ifname=$(echo "$ifnames" | awk '{print $1}')
        lan_ifnames=$(echo "$ifnames" | cut -d ' ' -f2-)
        # 多网口设备配置
        # 配置WAN
        uci set network.wan=interface
        uci set network.wan.device="$wan_ifname"

        # 查找 br-lan 设备 section
        section=$(uci show network | awk -F '[.=]' '/\.@?device\[[0-9]+\]\.name=.br-lan.$/ {print $2; exit}')
        if [ -z "$section" ]; then
            # 创建 br-lan 设备
            echo "Creating device 'br-lan'." >>$LOGFILE
            uci -q add network device
            uci set network.@device[-1].type='bridge'
            uci set network.@device[-1].name='br-lan'
            uci set network.@device[-1].igmp_snooping='1'
            # 添加LAN接口端口
            for port in $lan_ifnames; do
                uci add_list "network.@device[-1].ports"="$port"
            done        
        else
            # 删除原有ports
            uci -q delete "network.$section.ports"
            # 添加LAN接口端口
            for port in $lan_ifnames; do
                uci add_list "network.$section.ports"="$port"
            done
        fi
        # 添加LAN接口端口
        for port in $lan_ifnames; do
            uci add_list "network.$section.ports"="$port"
        done
        echo "Updated br-lan ports: $lan_ifnames" >>$LOGFILE

        uci set network.lan.device="br-lan"
    fi

    # LAN口设置静态IP
    if [ -n "$lan_ip_address" ]; then
        uci set network.lan.proto='static'
        # 多网口设备 支持修改为别的管理后台地址 在Github Action 的UI上自行输入即可 
        uci set network.lan.netmask='255.255.255.0'
        # 设置路由器管理后台地址
        uci set network.lan.ipaddr="$lan_ip_address"
    fi

    # 配置WAN口
    # PPPoE设置
    if [ -n "$pppoe_username" -a "$pppoe_password" ]; then
        uci set network.wan.proto=pppoe
        uci set network.wan.username="$pppoe_username"
        uci set network.wan.password="$pppoe_password"
        uci set network.wan.keepalive='5 5'
        # 配置WAN6
        uci delete network.wan6
        uci set dhcp.lan.dhcpv6='server'
        uci set dhcp.lan.ra='server'
        uci set dhcp.lan.ra_preference='medium'
        uci commit dhcp
        echo "PPPoE config done." >>$LOGFILE
    else
        uci set network.wan.proto='dhcp'
        # 配置WAN6
        uci set network.wan6=interface
        uci set network.wan6.device="$wan_ifname"
        uci set network.wan6.proto='dhcpv6'
    fi

    uci commit network
fi

exit 0