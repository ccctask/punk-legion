## 1. 私人经营入口
- [x] 1.1 私人布局及持久化、版本、扣费与并发
- [x] 1.2 核心与五种设施、道路与电力、入口保护
- [x] 1.3 Godot 游戏入口、触控预览和布局编辑
- [x] 1.4 重登与旧布局快照复测、界面截图
- [x] 1.5 主代理独立验收

子代理：python -B services/profile/check_base.py 与真实 Godot 4.6.1 窗口分别输出 BASE_PASS 与 BASE_UI_PASS。复测的坐标、冻结 v6、移动后 v7、两账号隔离与断路/重叠回滚见 docs/player-profile.md，画面见[桌面基地截图](base-desktop.png)。初始核心加五座可建设施使用组合灰盒，Android 触屏及正式建筑模型待验证。

主代理实窗从游戏入口验证六类设施、放置、移动与冻结，[实窗日志](verification/root-godot.log)。Android API 35 模拟器从档案注册，正常触控放置冶炼厂至 (3,2)，布局 1→2，新增 2 点供能需求，[模拟器画面](verification/android-foundry.png)。使用独立数据库重登、冻结版本、断路及越界/重叠检查通过。
