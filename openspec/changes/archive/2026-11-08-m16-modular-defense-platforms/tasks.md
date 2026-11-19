- [x] 1.1 实现固定底座与实体部件唯一占用、兼容校验、旧塔/旧场次兼容和原子归还。
- [x] 1.2 私有基地正常操作可建平台、查看兼容武器或功能件、装卸与拆除；复用资产库真实模型。
- [x] 1.3 实现权威供能和两类装配的实际防守动作，冻结装备与场次；测试并发、重试、断服与恢复。
- [x] 1.4 主代理实测一件部件在仓库、平台、自有机体间往返，核对防守实录、受损维修效果与旧档。

正常入口复测 python -B services/profile/check_platforms.py --godot <Godot> --capture <截图>。v16 升级保留旧布局和冻结回放；同件并发安装仅一方成功，塔和机体不能同时占用，拆回实物 ID 不变，装/拆前后财富相同，断服后回放和归属一致。冻结的维修臂对受损驻防机产生有上限的有效恢复。[开发回归](verification/dev-platforms.log) · [平台实物与装配面板](verification/platform.png) · [维修底座](verification/platform-base.png) · [操作手册](../../../../docs/player-profile.md#私人基地的模块化防御平台)。

主代理验证实物存取、跨机体/底座并发排他和冷启。相同袭击分别为空台 0 次动作、气炮 12 发、维修臂 2 次共修 4；12 组历史模拟与真实 1005 逐帧相等。已锁定旧袭击从 v15 升到 v16，42 张旧表逐行一致，回执与回放一致。正常客户端装拆、部件财富值不变、小屏回放目标及数额通过。[实物转移](verification/root-transfer.log) · [同场与旧版](verification/root-replay.json) · [运行中迁移](verification/root-active-upgrade.json) · [操作验收](verification/root-ui-final.log) · [最终回放](verification/repair-replay.mp4)。
