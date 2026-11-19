## 1. 资源与结算
- [x] 1.1 版本迁移、有限库存、蓝图和稳定实例 ID
- [x] 1.2 制造、入场和服务端结算，事务与幂等回执
- [x] 1.3 正常入口查看背包、制造、账本
- [x] 1.4 核心回归测试、重启恢复及并发与不足情形
- [x] 1.5 主代理独立验收

## 主代理独立复验
从运行中的旧容器提取 schema 1 服务代码，建立隔离的旧账户和机体；以当前代码连续初始化两次，机器人编号与名称保存，初始资源只发一次。八个并发请求制造同一炮臂，得到相同实体 ID，结构材料 12→9。耗尽通用零件后继续制造，操作失败且库存与账本完整回滚。
从 Godot 游戏入口运行 `res://profile/tests/inventory_ui.gd`，通过注册、制造、查看回执、持票离开与重新登录对账。隔离复验 `tests/room-ledger-smoke.ps1` 场次 9f284405d5b7257f2193f8d6：档案停服、房间重启、恢复投递后两个账户各仅一条同场奖励，pending=0。另行运行 `python -B services/profile/check_inventory.py`，通过迁移、重试、余额不足回滚、断服恢复与账本复核。

子代理自测证据：python -B services/profile/check_inventory.py 输出 INVENTORY_PASS，Godot --headless --path game --script res://profile/tests/inventory_ui.gd 输出 INVENTORY_UI_PASS。真实房间端 tests/room-ledger-smoke.ps1 验证断档案、场次结算、重启后两席各一笔。主卷 /data/pre-m08-20261108-130808.sqlite 保留升级前快照，实际 3 个旧账号的 3 台原机体与 3 条初始回执逐项一致。详见 docs/player-profile.md。

追加待修：双席战报应先作为一个批次原子写入房间持久卷。此前逐席写文件，在两个文件写入之间进程终止时可能遗漏后席。正常停服与重启用例已复验，等待覆盖这个更早的中断位置后通过最终验收。

主代理用独立双容器重跑中断用例，场次 cb15502e12170442dce2f209。一次写入的清单包含两席，确认首席后停止房间并加入旧格式重复记录。进程恢复后两账户各只有一份该场奖励，待处理目录清空。已修复并关闭上述待修项。

