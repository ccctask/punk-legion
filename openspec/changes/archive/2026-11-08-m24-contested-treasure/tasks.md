- [x] 1.1 事件生成与消退、独立 PVP 入口及玩法风险说明。
- [x] 1.2 单人／预组队匹配、成员确认与实际指挥。
- [x] 1.3 争夺、携带上限、撤离与个人账本。
- [x] 1.4 实战录像、争抢并发、断线／重启和重复结算回归。
- [x] 1.5 主代理复验并记录核心版本稳定性和 PVE 回归。

主验已在隔离档案实际运行匹配与个人结算逻辑，以测试时钟核对候场截止、事件轮换、双方同时拾取同一货物、携带中库存不变、撤离后只到账一次和未撤离者到期解锁。未确认的受邀者可继续普通 PVE，拒绝秘宝邀请保留原探索。另复跑纯 PVE 九十日模拟。实际双队 Godot 画面、房间重启及网络并发待复测。[业务场景](verification/root-treasure-flow.log) · [脚本](verification/root_treasure_flow.py) · [纯 PVE 回归](verification/root-ordinary-pve.log)。

主验使用原 1002 后端生成 v14 付费方案栏及进行中的 PVE 账号，迁移后 43 张原表逐行一致，原场次可继续结算。实测两个档案进程重启边界（持货、撤离后），满仓玩家有 1 件带出记录而实际增加 0，重复撤离只返回原回执。组队编制验证了 6+6 台轻机准入；6+7 或 6 台满 24 点重机再加援机均拒绝，撤销后所有机体可用。[迁移](verification/root-beta-migration.log) · [重启满仓](verification/root-treasure-restart.log) · [预算](verification/root-treasure-budget.log)。

五个独立 Godot 客户端经大地图分别进入两场实际 ENet 对抗，2 人对 1 人及 1 人对 1 人。每场双方同时抢同一物件仅一席拿到；从五卷快照在新容器恢复已撤离者与另一场持货者，持货者回来撤离，重启后原回执一致。五席最后均解锁。主验无头，参看开发图形录像；本轮 4 次拾取 69–115 ms，5 次撤离 56–1629 ms，30 次档案请求 p95 为 214.56 ms。[双房间主验](verification/root-live/live.json)。

开发自测及图形实战录像见[证据记录](verification/developer-report.md)，规则与重跑入口见[限时秘宝](../../../../docs/contested-treasure.md)。

主代理最终用五个独立客户端进入两场权威房间，复验唯一抢拾、撤离、占用解除和五卷恢复。并发档案探针 28 次、错误 0、p95 299.41ms，40 次移动 p95 394ms。前次繁忙复跑等待控制脚本回执超时，该轮未计为成功。单独重跑通过。[最终样本](verification/root-batch-retry/live.json)；开发自测及先前独立的持久化、仓满和迁移回归见 verification。
