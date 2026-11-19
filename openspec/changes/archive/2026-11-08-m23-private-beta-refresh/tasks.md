- [x] 1.1 核对 M14/M06 定稿并按差异递增签名，记录快照和 APK。
- [x] 1.2 原位更新与正常入口验证、旧资产对账、隔离网络和健康历史复测。见 [安卓升级前](verification/old-device.log)、[升级后](verification/new-device.log)、[旧包更新提示](verification/old-update-required.png)、[原账号](verification/new-profile.png)、[线圈港](verification/new-coil-preview.png)、[账本](verification/assets-after.log)、[五路握手](verification/transports.log)、[回退](verification/rollback.log)和[健康记录](verification/health-after.json)。
- [x] 1.3 标注连接范围与版本，主代理独立验收。

主代理在安卓模拟器强停后冷启 1007，再触屏进入已联网的试车台。六容器运行，协议 3 接受，旧协议 2 收到升级提示；首次安装时间保持。已核签名、源文件清单与五路 ENet。此包适用本机 Docker 与安卓模拟器。已另立 M17 处理私人基地首玩提示的小屏裁切。见[冷启](verification/root-1007-entry.png)与[联网试车台](verification/root-1007-range.png)。
