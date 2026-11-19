# friends-and-aid Specification

## Purpose
规定好友双方同意后可以参观、分享装配定义与派遣真实机器人，明确营地参战预算、指挥归属、召回时点与战后维修责任。

## Requirements

### Requirement: 好友自愿参观与方案分享
系统 SHALL 支持双方同意的好友关系、只读基地参观与不转移实体部件的装配分享。
#### Scenario: 缺少零件
- **WHEN** 接收者查看好友分享的配置且缺少其中的部件
- **THEN** 可预览定义与缺件，保存遵循账号容量，实装继续检查本人库存。

### Requirement: 有限预算内的真实援助
好友 SHALL 能以自有机体协助进攻或驻防，并在战斗中只指挥自己的机组。
#### Scenario: 多人同时派同一实体或超额增援
- **WHEN** 对一台机体、一个营地有并发派遣或总点数／单位数超过上限
- **THEN** 服务器仅接受符合归属、闲置和剩余额度的组合，其他请求不会占用实体或产生战报。
#### Scenario: 召回和处理战损
- **WHEN** 援助者在锁定前、战斗中或战后召回，或关系解除、队友掉线和结果重投
- **THEN** 机体最多参加一场，最终回到原主人且同场只计一次战损；维修费用归原主人，好友仓库不被直接扣款。

### Requirement: Shared robot fits identify each slot
The recipient SHALL see the hull, each equipment slot supported by that hull, its installed part or empty state, and their own new-install deficits in workshop terminology before saving a shared fit.
#### Scenario: Distinguish support roles
- **WHEN** the recipient selects a shared repair, jammer or empty-utility fit on a frame with a utility interface
- **THEN** the selected fit identifies its utility or empty slot and lists missing parts with quantities, and saving preserves that definition without transferring parts.
#### Scenario: A shielded crawler and a light wheel
- **WHEN** a recipient inspects the two shared definitions
- **THEN** the crawler details identify its front armor and the wheel lists its three supported interfaces; neither shows unsupported interfaces as vacant slots
#### Scenario: Save a shield design after obtaining a spare
- **WHEN** a recipient owns a free shield, opens the shared shielded crawler and saves its definition
- **THEN** that shield is absent from the deficits, the saved definition retains the armor and both players retain their original parts

### Requirement: Friends actions take precedence over automatic reads
The friends UI SHALL honor an enabled manual action on the selected target during an automatic social refresh and provide visible feedback while a submitted action is pending.
#### Scenario: Save during background refresh
- **WHEN** a player taps Save while a background read is pending and repeats the tap while the save is in progress
- **THEN** the client submits the originally selected share once and displays the authoritative result.

### Requirement: Personal repair allowance for damaged defensive aid
The camp settlement SHALL entitle a damaged friendly reinforcement on the defending side to a one-time reduction of one structure material on the owner's next repair of that injury. The owner's actual share is one common component.
#### Scenario: Accepted aid defends a public camp
- **WHEN** a deployed defender belonging to a helping friend returns with real combat damage
- **THEN** the dispatch interface explains the rule, and the robot's personal condition and repair bay show the same reduced price that is charged on successful repair.
#### Scenario: Entitlement cannot be transferred or monetized
- **WHEN** a result or repair is retried, the unit is restored by relief or recycled, or a later unrelated injury occurs
- **THEN** no materials are granted, the recipient pays nothing, and no discount is duplicated or passed to another injury; ordinary defenders, attacking aid and undamaged aid receive no allowance.
