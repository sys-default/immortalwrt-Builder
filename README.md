# immortalwrt-Builder
使用GitHub Actions编译immortalwrt x86-64 架构的固件

## 项目介绍
使用GitHub Actions编译immortalwrt固件，支持自定义编译选项。

使用immortalwrt放出的 ImageBuilder 工具进行固件构建

## 基本用法步骤
1. fork本项目
2. 在fork后的项目中 点击【action】 找到需要的工作流后 run-workflow

## 该固件默认属性？(必读)
- 该固件刷入【单网口设备】默认采用DHCP模式,自动获得ip。类似NAS的做法
- 该固件刷入【多网口设备】默认WAN口采用DHCP模式，LAN 口ip为  `192.168.100.1` <br>其中eth0为WAN 其余网口均为LAN
- 若用户在工作流中勾选了拨号信息 则WAN口模式为pppoe拨号模式。

---

## 感谢项目
- [immortalwrt](https://github.com/immortalwrt/immortalwrt)
- [Image-Builder](https://github.com/noviachen/Image-Builder)
- [ImmortalWrt-ImageBuilder](https://github.com/wukongdaily/ImmortalWrt-ImageBuilder)
