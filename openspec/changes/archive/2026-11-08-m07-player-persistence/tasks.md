## 1. 实现与验收
- [x] 1.1 测试账户、会话轮换、SQLite 存档与实例
- [x] 1.2 任务互斥、取消或完成，事务回滚与归属
- [x] 1.3 游戏内档案入口、容器部署、备份恢复与版本检查
- [x] 1.4 双账号、重启与恢复自测并交付复测说明
- [x] 1.5 主代理独立验收：实际 Godot 档案入口及隔离 compose 复验，三次启动和恢复、账户隔离、过期会话及旧任务不覆盖新任务全部通过。

主代理通过运行中的 compose 服务端独立并发派发四种不同任务。结果一条 200、三条 409。新登录会话保留同一任务 ID，旧会话读档得到 401；新会话完成该任务后机器人回到空闲。容器重建、恢复和客户端档案入口需另验。

子代理自测通过（Godot 4.6.1、原生 Python 3.14.2、容器 Python 3.13）。执行 `python -B services/profile/check_profile.py` 及其 `--compose` 分支均得到 PASS，覆盖四方竞争只成功一次、过期任务清退失败无部分写入、两账号隔离、会话轮换、三次启动及完整备份恢复。用 Godot 运行 `--headless --path game --script res://profile/tests/profile_ui.gd` 输出 PROFILE_UI_PASS。启动方式、接口与恢复命令见 docs/player-profile.md。开发机已启动本地容器；Android 本次未测，1.5 由主代理独立复验。

