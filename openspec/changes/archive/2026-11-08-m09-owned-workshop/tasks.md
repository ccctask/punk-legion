## 1. 开发与验收
- [x] 1.1 账户方案、机体装配数据与存档迁移
- [x] 1.2 服务端制造、拆装、互斥与幂等
- [x] 1.3 游戏内选择、预览、保存与改装
- [x] 1.4 并发、余额和部件对账、重登测试与演示记录
- [x] 1.5 主代理独立验收

## 开发自测

- python -B services/profile/check_workshop.py 核对 M03 全目录数据、版本 2 档案迁移、同版不同实体、并发重投、争用一个部件、资源不足整笔回滚、维修互斥、满包换件、重登和机库/编队容量。
- python -B services/profile/check_inventory.py 从 schema 1 覆盖现有背包、会话、账本和备份恢复。两组自测均通过。
- Godot 4.6.1 渲染窗口在 960×540 下，从试车台进入档案并注册，通过工坊保存光带方案、制造两台机体、拆装与重登预览。制造编号 7f31346a48e24055af339f46030e7d2f 和 a381dca1ac7d4f658fa48c46462f39af；部件 04eb286b3fba4885a60279f126ccfa63 在拆卸与回装后保持身份。
- 复测时启动隔离档案容器，将 PROFILE_URL 设为该服务，运行 Godot --path game --script res://owned/tests/workshop_flow.gd。另设 OWNED_SCREENSHOT 为本机绝对 PNG 路径可保存画面。

实窗从档案进入工坊并重登：[工坊](verification/root-godot.png)、[日志](verification/root-godot.log)。另用独立数据库并发抢装同一部件，只有一台成功，失去竞争的请求完整回滚。相同制造回执仅创建一次。
