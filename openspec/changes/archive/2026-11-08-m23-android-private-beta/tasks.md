- [x] 1.1 可更新的包名、签名和版本策略，内测服务公开地址配置。
- [x] 1.2 两个实际安装版本、签名与文件校验，安卓安装升级及重装恢复。
- [x] 1.3 旧协议处理、断线与前后台回归、模拟订单状态。
- [x] 1.4 内测说明、版本兼容、回退与已知问题，保留后续渠道验收清单。
- [x] 1.5 主代理独立验收候选包与交付材料。

主验已从 Android 15 模拟器系统网络访问宿主 10.0.2.2:24670，并在隔离的 24860 端口复验账号、库存、延迟发货、退款。首次连接说明应标出模拟器宿主地址以及档案 TCP 与房间 UDP 的区别。该项仅覆盖网络路径，尚待签名候选包从正常游戏入口进行升级和重装验收。[网络实测](verification/root-emulator-network.log) · [旧包签名及版本基线](verification/root-package-baseline.log)。

主验从两个实际 APK 独立验证包名 dev.punklegion.beta、版号 1001／1002、相同 v2/v3 签名与双 ABI；包内的档案端点为 10.0.2.2:24980。协议 1、2 可达，0、3 收到 426。见 [签名与哈希](verification/root-beta-signatures.log)、[协议实测](verification/root-beta-protocol.log)。

主验直接读取模拟器安装版本与测试服档案，在 1002 已安装时确认旧机体及其三个安装件 ID、涂装、方案、库存、7 格容量及两笔订单历史与 1001 基线一致。[账本复验](verification/root-beta-ledger.log)。审图发现 960×540 首屏状态说明压到右侧机体插图，已交修订，待新包复核。

1002 干净重装复核：包管理器首次安装时间已从 07:08:29 变为 07:21:15，晚于 07:15:09 的覆盖升级。核对重装后的玩家档案与工坊画面、同机体 ID、薄荷涂装、七格与已发货订单，再次核对服务器库存无差异。[包管理器记录](verification/root-beta-reinstall.log) · [重装后工坊](verification/root-reinstalled-store.png)。

开发自验已在 Android 15 的 960×540 模拟器保存[1001 注册](verification/device-registered.png)、[覆盖更新后的机体](verification/device-updated-profile.png)、[原位更新时间](verification/device-update-times.log)、[1002 外观与七格](verification/device-updated-store-live.png)、[前后台恢复](verification/device-updated-background.png)、[旧协议被拒绝](verification/device-old-rejected.png)、[停服重连提示](verification/device-offline-reinstall.png)及[全新安装后登录并恢复权益](verification/device-reinstalled-store-live.png)。1001 中机体、方案和薄荷涂装通过正常界面创建。方案栏模拟订单通过同账号 HTTP 接口发货后，从 1002 商店和重装后的档案核对。重装前后的机体与部件 ID、状态、库存、蓝图、两笔订单完整历史及装配方案逐项相同。[重装对账](verification/device-restored-ledger.log)

修订首屏后，桌面实际渲染窗口自测点通重试、反馈与进入试车台，核对中文说明边界在插画左侧，缩小窗口时可以滚动。[960×540](verification/entry-960.png) · [640×360](verification/entry-640.png) · [构建、兼容与回退](../../../../docs/android-private-beta.md)。最终递增候选及 M24 五路 UDP 需随整合快照复测。

1004 与最终版之间有一处导出输入更改，秘宝房间脚本属于 APK 资源，故递增并重签为 1005。1005 与六个运行容器使用同一份 rc-1005 不可变快照，内测签名与 1001 相同。[输入差异](verification/rc-1004-input-delta.log) · [最终包版本、APK/源码哈希与签名指纹](verification/PunkLegion-beta-1005.json) · [包内配置](verification/rc-1005-installed-config.log) · [五端点 ENet 握手](verification/rc-1005-ports.log)。

1002 覆盖安装 1005 后首次安装时间 07:21:15 保持一致。Android 15 正常入口已点通重试、复制反馈和进入，960×540 横屏各行均在插画左侧。[安装前](verification/before-1005-install.log) · [安装后](verification/after-1005-install.log) · [首屏](verification/rc-1005-welcome.png) · [反馈](verification/rc-1005-feedback.png) · [试车台](verification/rc-1005-range.png) · [同机体编号](verification/rc-1005-profile.png) · [七格与薄荷订单](verification/rc-1005-store.png)。

服务器在原卷升级到 v15，开发复验对照仍一致。另在全新隔离环境还原五个 v14 卷并以原 v14 镜像登录，机体、装配、库存和两份模拟订单均逐字段匹配。完成后移除临时恢复工程；内测服继续运行。[1005 账号核对](verification/rc-1005-account.log) · [隔离回退](verification/private-beta-rollback.log)。实际手机温升/耗电、外网与渠道平台由后续设备和网络决定。

主代理在 Android 15 模拟器独立冷启 1005，确认协议 2 已连到本机服务，实际点击进入游戏后连接试车台二号席。安装器保留首次安装时间，版本升级为 1005。APK 完整哈希与签名匹配版本单。[签名与服务协议](verification/root-1005-release.log) · [内测入口](verification/root-1005-entry.png) · [试车台](verification/root-1005-range.png)。
