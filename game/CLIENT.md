# 机库试车台客户端

适用 M01 桌面调试样板。开发子代理维护，Godot 4.6.1 standard 已自测。项目入口为同目录 project.godot。Windows 验收机器使用 Compatibility 渲染器。

## 编辑器双实例

1. 从仓库根目录按 [容器配置](../compose.yaml) 启动本机房间，确认控制台出现 ROOM_READY 和 UDP 端口 24567。
2. 在 Godot 项目管理器导入 game/project.godot，等待模型首次导入。编辑器 Debug 菜单把运行实例数设为 2，按 F6 运行已打开的 range.tscn 或按 F5 运行项目。每个实例会连接 127.0.0.1。
3. 两个窗口分别显示本机席位 01 和 02。金色圆环标识自己，青色标识队友。分别在场地内点击不同位置，观察两台机器人在两个视图移动。
4. 在其中一端点击断开，在房间保留时间内点击连接。该窗口重新取得原席位和当前位置。关闭整个进程将结束该客户端内存中的重连凭据。
5. Android 运行时在地址栏输入宿主机局域网 IP 并连接。局域网端口映射和真机导出、安装、后台恢复验收按 M00/M05 记录。

## 双客户端自动复测

启动干净的测试房间，再同时运行两份下列命令。GODOT 表示同版本编辑器的可执行文件。测试通过真实 viewport 点击发出移动指令，核对两个机器人展示节点到达目标，并触发断开与重连按钮，末行显示 CLIENT_SMOKE_PASS。

```text
GODOT --path game --script res://client/tests/room_view_smoke.gd
```

可用 ROOM_PORT 选择独立测试端口，服务端与两个客户端设同值。将 CLIENT_CAPTURE_DIR 指向现有目录可保存两个图形窗口画面。无显示器环境可加 --headless，需先用编辑器完成资源导入。开发自测的截图和日志保存在该变更 evidence 子目录。

## Android 调试包

Android Debug 预设导出横屏 APK，包名 `dev.punklegion.client`，支持 arm64-v8a 和 x86_64。使用与编辑器匹配的 Godot 4.6.1 standard Android debug 导出模板。编辑器设置的 Export → Android 中填写 JDK 和 Android SDK 目录，首次导出会在当前用户目录创建调试签名。项目打包时包含各玩法场景与网络权限。

从仓库根目录创建 `build/android` 并执行以下命令。把 GODOT 替换为编辑器可执行文件。导出后用 Android SDK 的 apksigner、aapt 和 adb 核对包与安装结果。

```text
GODOT --headless --path game --import
GODOT --headless --path game --export-debug "Android Debug"
apksigner verify --verbose build/android/PunkLegion-debug.apk
aapt dump badging build/android/PunkLegion-debug.apk
adb -s DEVICE install -r build/android/PunkLegion-debug.apk
```

模拟器用 `10.0.2.2` 连接映射在宿主机的容器端口。Android 真机用同一局域网的宿主机地址，需将容器 UDP 端口显式映射到该局域网地址。默认回环映射用于本机桌面及模拟器。

调试图标来自资产库 `PL_SteamCrawler/r07-mobile-optimized` 的 `iso-front-right-upper-640.webp`，图片 SHA256 为 `2765f2736e9a6584637206ec996c34c24682d78bcb4c3d35d8dc150717378f98`。

## 发布构建的服务地址

适用于 Godot 4.6.1。构建负责人从[公开端点示例](../deploy/runtime_endpoints.example.cfg)复制一份到游戏工程根目录，命名为 `runtime_endpoints.cfg`。替换各服务的公开主机或域名与端口，档案填写完整 HTTP(S) 服务根地址，生产部署使用 HTTPS。房间、独行探索、组队探索和营地争夺各自使用一个 UDP 端口。预设将这个配置打入包，人员口令、签名密码与容器内部密钥只保存在相应环境。

正式模板通过 `GODOT --headless --path game --export-release "Android Release"` 打包；开发机须先安装 4.6.1 的 Android release 模板，并在导出器的凭据设置里提供本地签名。Windows 链路验收使用 `--export-release "Windows Release QA"`。创建对应的 build 输出目录后运行命令。打开发布程序将直接使用配置内的服务；缺项时对应玩法显示配置错误。测试完后应移除 staging 端点，以免用于下一次交付。

调试时可用 `ROOM_HOST`、`ROOM_PORT`、`PROFILE_URL`、`SOLO_HOST`、`SOLO_PORT`、`PARTY_HOST`、`PARTY_PORT`、`CAMP_HOST` 与 `CAMP_PORT` 分别指定。房间支持 `host:port` 或 IPv6 的 `[host]:port`。未另指定探险主机时使用档案 URL 的主机部分，未指定其端口时使用各自默认 UDP 端口。模拟器默认宿主地址为 `10.0.2.2`。

Windows 上运行 `python tests/check_runtime_environments.py --godot <Godot控制台程序>` 可复测三种环境。脚本在临时工程中加入测试观察器，保留试车台作为主场景，通过按钮进入档案。它分别导出配置完整与缺项的正式模板包，保存到 `build/runtime-verification/`。默认使用本机 UDP 24681 和 HTTP 24682，可用 `--room-port` 和 `--profile-port` 调整。测试结束后临时服务关闭；手工验收时，在对应端口启动房间与档案服务后双击测试包即可。


## 战场音效

在私人基地左上角打开「基地菜单」，点「音效」可选择静音、低、中或高，默认中。试车台底部的「音效」读取同一本机设置。保存成功后，当前战斗立即应用新音量，下次启动游戏也会保留。静音会停止正在播放的声音，恢复音量后可听到当前行进的履带声和新触发的战斗提示。

单人试战、双人演习、锈轨探索和秘宝争夺共用同一个战场音效场景。履带根据视野内己方是否行进启停，双足机按机械足落地播放脚步。蒸汽声跟随实际武器动作，双音提示己方耐久从 35% 以上进入危险区。移动、射击与危险提示各占一个声部。秘宝按本席位的左右阵营识别己方。断线、席位被接管、本人结算或退出即停止，重连后从首个确认画面重新记录动作。

三个原创单声道 WAV 由项目的[确定性合成脚本](../tools/audio/build_cues.py)生成，22,050 Hz、16-bit PCM。履带组合两次机械扣合，蒸汽用固定种子的滤波噪声与短低频压力声，危险提示使用 625/835 Hz 双音。修改时从仓库根执行 `python tools/audio/build_cues.py`，再用项目指定的 Godot 编辑器导入资源并核对三份 WAV 的 .import。全部声音由本项目合成，未使用外部样本或配乐。

复测 Android 三人探索帧时，请在验收模拟器启动时将物理帧缓冲设为原生 540×960（横屏 960×540），先点掉系统首次全屏提示并确认首领在画面内。只设 `wm size 540x960` 会保留原来的物理显示配置，属于另一项对照。设备配置、真实三方回执、P95 取法与当前预算见 [M06 显示及采样记录](../openspec/changes/m06-device-battle-baseline/verification/compositor.md)。
