# authoritative-battle Specification

## Purpose
为两位指挥员提供同场协作的权威战斗。服务端检查各自机组的指挥权限，驱动目标和伤害进程，在掉线恢复与最终结算时向两端交付一致状态。

## Requirements

### Requirement: Shared authoritative squad battle
The room SHALL run one shared battle after both seats are ready, simulate owned squad commands on the server, and deliver a single authoritative outcome.
#### Scenario: Two commanders fight together
- **WHEN** two ready seats join and issue movement or focus orders
- **THEN** both clients observe the same battle, ownership, unit health, and final result.
#### Scenario: Resume battle
- **WHEN** a retained seat reconnects before its grace period expires
- **THEN** it receives the current battle or its retained final result with the same battle ID.
#### Scenario: Command validation
- **WHEN** a seat sends repeated or foreign-unit commands
- **THEN** the server preserves the accepted orders and ownership.

### Requirement: 战术目镜加快新目标锁定
权威服务 SHALL 让带战术目镜的参战机体对新合法敌人更早完成瞄准，在同目标上的持续射击间隔保持同款武器的既有设定。

#### Scenario: 两台相同武器锁定新敌
- **WHEN** 两台机体在相同条件下开始锁定同一个可攻击目标且冷却已结束
- **THEN** 带目镜者更早打出第一发，随后两台各自的相邻射击间隔相同

#### Scenario: 集火、武器冷却与干扰
- **WHEN** 玩家重复指定原目标、切到新目标，或敌方干扰延后下一次武器动作
- **THEN** 只有真正更换目标才重新瞄准，冷却与干扰约束仍有效，切目标不能提早结束武器冷却

#### Scenario: 同一机体参与秘宝争夺
- **WHEN** 装有战术目镜的玩家机体在秘宝区域更换合法敌人
- **THEN** 秘宝权威服务体现相同的首发优势，本轮新场次的玩家断线重连后武器冷却继续生效
