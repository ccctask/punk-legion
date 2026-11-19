# device-battle-baseline Specification

## Purpose
规范移动设备上的战斗性能对照，按玩家实际看到的场面、关键动作时序和系统呈现帧间隔评价候选改动。验收记录应说明设备、场景、交火状态及样本覆盖范围，并保留可供独立复算的原始测量。

## Requirements

### Requirement: 满编循环动画优化按阶段验证
性能验收 SHALL 独立比较满编机械部队的动画评估频次、玩家关键动作和实际呈现。
#### Scenario: 安卓对照满编接敌
- **WHEN** 改变非焦点机体的循环动画采样频次
- **THEN** 复核动画时钟、攻击和死亡反馈并按相同战斗画面分别记录两种顺序的基线和候选帧时，根据预设门槛决定是否交付。

### Requirement: 正交战场投影对照
优化方案 SHALL 依据完整关卡的可见范围设置远界，并核对地标、机体、投影覆盖及满编接敌的实测成本。
#### Scenario: 缩短远裁剪并调整方向光分区
- **WHEN** 对普通泵房相机提出更短远界或不同方向光分区
- **THEN** 检验地图边界和战斗关键画面，按两种顺序验证收益，合格后再进行安卓联机复验。

### Requirement: Pump marker batching qualification
The project SHALL qualify any pump ring and health marker batching candidate against the current renderer before enabling it.

#### Scenario: A full squad fights by the west valve
- **WHEN** the candidate and reference draw the same 24-unit encounter
- **THEN** compare gameplay indicator fidelity and draw submissions in both orders before evaluating Android frame time.

### Requirement: Qualify crawler geometry LOD in the pump encounter
The project SHALL measure visible primitive counts and inspect unit readability before testing a more aggressive crawler geometry LOD on Android.

#### Scenario: Change only the crawler model bias
- **WHEN** the full west-valve encounter is drawn at the same pose, camera and resolution
- **THEN** both test orders must demonstrate a reduction of at least ten percent in visible primitives and retain equipment and faction readability before entering mobile timing qualification.
