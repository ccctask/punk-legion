- [x] 1.1 报价资格与重试、并发校验。
- [x] 1.2 预览说明、可操作状态与正常双机回收。
- [x] 1.3 主代理在 Godot 与 Android 复验。
- [x] 1.4 到期事件时间、父子机况与到期自动刷新；停留和重新打开两种情形。

[开发自测记录](verification/recycle-clock.log)。复测命令为 `python services/profile/check_recycle_quote.py --godot <Godot可执行文件>`。

主代理在同一 API 35 模拟器与真实旧库升级后的账号操作。原机体 7771202d048b41a1ad77b8ac34583cd6 显示最后一台不可回收。06:00:20 UTC 入列，停留在档案；06:00:50 UTC 完成，上方任务和下方详情同时待命，可立即派遣。实际证据：[回收说明](verification/android-last.png)、[维修入列](verification/android-paid.png)、[到期状态](verification/android-ready.png)、[重新出发](verification/android-dispatch.png)、[独立双机并发及旧报价回归](verification/root-quote.log)。
