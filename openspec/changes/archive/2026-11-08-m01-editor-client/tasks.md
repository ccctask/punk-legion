## 1. 实现与自测
- [x] 1.1 组合客户端场景、模型展示与触控操作
- [x] 1.2 Godot 4.6.1 两个真实图形进程和本地独立权威房间已通过双端移动、断开与重连；见 [开发自测日志](evidence/client-selftest.log)、[席位 1](evidence/seat-1.png)、[席位 2](evidence/seat-2.png)。客户端按 viewport 点击发出指令，服务端进程在 Windows 本机运行。容器、编辑器首验和 Android 真机由主代理另行复验。
- [x] 1.3 主代理独立桌面复验
- [x] 1.4 首轮 Android 模拟器联机、触控及工坊出击复验，证据见下。实体手机验证后移。

## 2. Android 调试构建
- [x] 2.1 配置匹配的导出模板、Android SDK、JDK 与横屏联网调试预设
- [x] 2.2 导出 APK 并核验签名、Manifest 和 SHA256，记录 Android 模拟器安装与触控移动结果。参见[构建记录](evidence/android-build.md)与[联机截图](evidence/android-emulator.png)。

主验在 Godot 4.6.1 编辑器按 F5 启动两个带 remote-debug 的实例。两个实际窗口各接收一次点地输入，容器记录不同席位的移动。席位一在窗口点击断开、连接后，服务端为新 peer 恢复原坐标，再次移动成功。[容器日志](verification/container.log) 最后一次两席 JOIN 起为本次编辑器检查。前一轮图形客户端控件回归亦在同一容器通过，截图见 verification/。Android 实机另验。

主代理在 API 35 的 960×540 横屏模拟器独立操作签名调试包（SHA256 3E12C10CB8884D936288E974D9CCC53C64DFB3A59E6369E7EA3C8D6E9B0B0AC1）。席位 2 点地后，容器记录 seq=3 和目标 (-0.987933, 2.099806)，进入装配台后记录 ROOM_RELEASE seat=2。工坊显示 12 台／24 点，出击后选择一队并移动，中继占领计时推进。[联网](verification/emulator-network.png)／[工坊](verification/emulator-workshop.png)／[战斗](verification/emulator-battle.png)。场景转换期间 logcat 报告一次 can_process 的 is_inside_tree 检查，已交回排查。该设备是模拟器。


主代理用新版调试包（SHA256 B0825CC4D9D027C787F2444D7919F8F1FEAC4B163B8984D68FECC914E9818063）重测。Android 15 模拟器的席位一从后台返回后，容器收到同一席位的第二条移动指令。其后手动断开并重连，服务端给新连接恢复原席位与位置 (1.935537, 0.761939)，再次点地成功。[容器日志](verification/emulator-resume.log)。当次进程 Godot 日志未再报 can_process 错误。

归档后干净构建复验。工作区尚无 Git 提交，本次将 rc-1005 冻结的 302 个输入文件建为临时本地仓库并重新 clone，逐件比对 SHA-256。检出目录没有 .godot 缓存。用 Godot 4.6.1 执行 --headless --editor --import 和 --export-debug "Android Debug"，无导入或导出错误。调试 APK 57,768,653 字节，SHA-256 901e7ff2f6c66a85aece5ef847e3a19bab12a666a1a83c435c44a2045db26fe1。Android 15 模拟器覆盖安装成功，从桌面冷启，点连接后在 Docker 日志观察到 ROOM_JOIN seat=2，画面显示两台机体和二号席位。该次冷启系统报告 5.458 秒。[模拟器原始启动录屏](../../../../docs/evidence/m01-android-debug-start.mp4)。
