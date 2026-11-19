# repair-recovery Specification

## Purpose
定义机器人战后损坏、服务端计时维修、有限回收与资源枯竭时的恢复途径，保证机体身份与战绩可追溯，并在重复提交或停服后正确记账。

## Requirements

### Requirement: Retained damaged robots and finite recovery
The service SHALL retain a defeated robot and its installed parts, prevent deployment while disabled, and support account-owned repair, voluntary recycling and bounded recovery.
#### Scenario: Repair across restart
- **WHEN** a disabled robot starts a paid repair and the owner reconnects after the due time
- **THEN** the same robot can deploy again, materials are charged once and workshop repair is distinguishable in its records.
#### Scenario: Insufficient resources and relief
- **WHEN** the account cannot field its minimum force and has exhausted ordinary resources
- **THEN** the player can recover a usable force through a limited nontransferable route, with no repeatable conversion of relief to profit.
#### Scenario: Voluntary recycling
- **WHEN** a player explicitly confirms an eligible idle asset for recycling
- **THEN** the transaction grants at most its stated conservative return, preserves historical identity and respects idempotency.

### Requirement: 预览显示实际回收资格
检修面板 SHALL 展示服务器判定的回收资格及实际返回物资。
#### Scenario: 账号最后一台机体
- **WHEN** 玩家查看最后一台机器人能否回收
- **THEN** 界面解释需要保留至少一台，不显示可领取材料承诺且不能提交确认。
#### Scenario: 报价后资格变化
- **WHEN** 其他操作使之前的有效报价失效
- **THEN** 提交时重新检查资格，界面可刷新原因；保留最后机体且不重复支付。

### Requirement: 到期机况与完成时间一致
客户端 SHALL 在维修到期后同步当前机体任务和检修详情，服务器应按预定到期时间记录完成事件。
#### Scenario: 跨过维修截止
- **WHEN** 玩家停留在档案内跨过截止时间，或在截止后重新打开页面
- **THEN** 同一机体各面板显示可用，允许派遣；维修完成事件时间等于服务端计划的到期时刻，重复读取不新增记录。

### Requirement: 供电修理站的并行检修
档案服务 SHALL 保留一个基础维修工位，基地至少有一座已供电的修理站时，再开放一个共享工位。单机维修为 30 秒。

#### Scenario: 两台同时维修
- **WHEN** 玩家已有一台在修并通过已供电站房或档案送修第二台
- **THEN** 两台按各自截止时间完成，每台只扣一次原价；工位占满时拒绝第三台且不扣费。

#### Scenario: 维修期间断电
- **WHEN** 两台在修期间所有修理站失去供电
- **THEN** 保留两台原截止时间，后续新任务按当前一个基础工位计算，恢复供电时可再次使用第二工位。

#### Scenario: 点击基地站房
- **WHEN** 玩家在私人基地建造模式点击自己的已建修理站
- **THEN** 可以查看当前可用工位、在修机体、剩余时间和受损机体报价，送修和完成结果与档案一致。

### Requirement: 送修前可核对材料
基地与档案 SHALL 使用服务端同次报价展示待修机体所需物资及当前库存。
#### Scenario: 缺料和补足
- **WHEN** 一种或多种送修材料不足
- **THEN** 玩家能读出各项缺口且送修禁用，刷新至恰好足额且有空工位后可以提交。
#### Scenario: 报价后库存被使用
- **WHEN** 同账号在提交前消耗材料
- **THEN** 服务端拒绝超支，保持工位和库存一致，玩家可以刷新到当前报价。
