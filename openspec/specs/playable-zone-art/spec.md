# playable-zone-art Specification

## Purpose
规定基地六类设施和回收场地形、目标及敌人的工业玩具视觉表现、冻结资源可追溯性、移动端辨识与实战点选的验收方式。

## Requirements

### Requirement: 可在游戏远景辨认的工业玩具场景
项目 SHALL 按已确认的建模规范发布可复用资产，让玩家在基地与回收场用轮廓辨认设施、采集点、撤离点与关键敌人。
#### Scenario: 基地建设
- **WHEN** 在游戏中摆放核心、仓库、冶炼、装配、修理和炮塔
- **THEN** 各设施显示功能对应的正式模型，保留真实占地、供电反馈、点击与炮塔活动轴。
#### Scenario: 关卡辨识与移动端验证
- **WHEN** 玩家从单人或组队入口进入回收场并采集、指挥、挑战首领
- **THEN** 资源类型、可通行区域、支援敌人及首领通过模型与场景可辨，关键目标可选中，记录安卓模拟器上的真实表现与性能。
#### Scenario: 模型发布交接
- **WHEN** 新建或更新一个本模块使用的模型
- **THEN** 可从索引查到源件、配方、资产库发布编号和 Godot 消费场景，导出物哈希与冻结版本一致。

### Requirement: Public camps communicate their resource and playable boundaries
The two public camps SHALL use authored industrial toy diorama scenes in preview and combat. Brass Yard shall depict structural-material handling and Coil Depot shall depict components and reels. Art shall correspond to the authoritative terrain.

#### Scenario: Choose and command in either territory
- **WHEN** a player opens the camp from its public map pin and enters its battle
- **THEN** its resource landmark is visible at gameplay scale, and the player can select their robots and issue an objective order without decorative geometry obscuring the objective or advertising a false route.

#### Scenario: Reproduce the art review
- **WHEN** an agent reviews the new camp scenes
- **THEN** the agent can locate their source releases, compare both camps from matched cameras, and reproduce the mobile visual and performance checks.
