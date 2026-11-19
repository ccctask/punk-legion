# Proposal

状态：G2/A04目录合同工具6/6限定签收，见verification/root-review.md；独立正式结果及归档准入已核。主责M03目录合同，关联M00测试工程、M04/M09/M16/M24消费者及装配入口；M07维护边界已6/6归档，本案不重跑其选集。

## Why

同一机器人定义由Godot常量和服务端JSON两份表示消费。已有check_workshop.check_catalog仅按源码形式解析并使用Python相等，不能证明引擎实际加载值，也不能区分布尔与数字漂移。按[只读输入](../../../../build/architecture-review/a04-contract-slice-input.md)补真正运行时校验，保护后续模块开发的公共定义边界。

## What Changes

- 复用现有隔离Godot/OwnedJob机制，以真实生产目录导出版本、底盘和部件，严格对照服务端实际消费的JSON。
- 增加四个有明确可比输入的生产装配/编队样例及比较器拒绝控制，报告字段差异、来源哈希、原输出和资源终态。
- 明确M03目录所有者、M09实体/事务边界及消费者执行差异；目录绿灯不扩大为跨玩法完整模拟等价。

## Capabilities

### New Capabilities

无。工程校验工具，不新增玩家能力；skip_specs=true。

### Modified Capabilities

无。沿用loadout-rules及engineering-baseline的可信定义、可追踪测试与边界合同，不改装配规则、费用、CP、战斗时序或失败语义；不为校验工具发明玩家规格。

## Impact

候选只改tests/godot的隔离导出/样例入口、tests侧Python比较与编排及测试文档。已有源码校验保历史用途，不整套搬运旧check_workshop或其旧schema夹具；不使用数据库/HTTP/ENet/Android/容器，不触当前试玩1077/r2或任何生产定义/模拟源。实际路径/预算按design最终AR与原正式执行锁签收；旧门已关，后续复验须新锁新run。
