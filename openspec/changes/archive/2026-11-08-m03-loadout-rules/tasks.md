## 1. M03
- [x] 1.1 定义可信部件、底盘、库存与编队样例。12 台轻型或 6 台重型均为 24 点。
- [x] 1.2 实现单机和整队共享校验。结果返回每台机器人解析后的部件、机体实体键、指挥点及战斗属性。
- [x] 1.3 接入真实机器人预览并显示费用及失败原因。[Godot 桌面截图](workshop.png)。
- [x] 1.4 Godot 4.6.1 运行 `--headless --path game --script res://loadout/tests/check_rules.gd`，结果 `loadout failures=0`。回归包含同一运行时 UI 的真实换装与拒绝后保留状态。OpenSpec 严格验证通过。
- [x] 1.5 主代理独立复验
主代理用 Godot 4.6.1 重跑 check_rules.gd，输出 loadout failures=0。核对用例含 12 轻与 6 重同为 24 点，以及换装失败保留预览状态。
