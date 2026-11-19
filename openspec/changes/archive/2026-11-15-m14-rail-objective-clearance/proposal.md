# Proposal

## Why

锈轨回收场三个采集实体与路由终点同址，现有导航只登记岩石，机器人可以走进模型。1078受控正常路由的A/B图已证明废轨堆遮挡机体与耐久；目标标签也与机体名字重叠。这是完整探索试玩的可读性与通行合同缺陷，应在继续整合候选前修复。

证据：[受控对照根签](../../m23-architecture-release-integration/verification/root-rail-visibility-diagnostic-a2-result-review.md)、[真实源码调查](../../../../build/architecture-review/m04-expedition-feedback-input.md)。受控证据不等于Android a3现场唯一归因。

[V a4](verification/root-readability-v-a4-result-review.md)已解除名字/HP压字，但后排机体仍进入附近Exit门柱。[实际实体输入](../../../../build/architecture-review/m14-exit-post-footprint-input.md)确认底盘/锅炉顶点落在闭合后柱内部，当前地图遗漏柱脚占地。补齐这处同一关卡的物理边界，保留门洞，才能沿正常寻路修正穿柱；不是隐藏门架或调整采证。

## What Changes

- 废轨堆、储能井、线圈库具有中心3×3格实体占地，复用现有寻路与视线遮挡；点地和目标路由均不能将机体送入该占地。
- 关卡定义独立于网络Mission和视觉资源，地图权威与场景消费同一地点/占地定义；守卫出生避开实体。
- 调整三个目标的标签布局，实际核验附近机体、名字及耐久可辨。
- 本版本新生成检查点原样续接；非法站内坐标拒绝恢复，不转换旧数据。派生其他地图保留自身布局。
- 为撤离门架的两柱脚单独声明静态占地，合并到rail障碍集合，门心与横向通道保持开放。该补项会改变真实LOS/路线，保守格覆盖明确接受，不称纯画面等价。

## Capabilities

### New Capabilities

无。

### Modified Capabilities

- `solo-expedition`: 锈轨单人及标准组队地图的实体占地、可达采集位置与近景可读性合同。

## Impact

主责M14，关联M15（标准组队共享地图）、M04（复用Field接口/既有信息呈现）、M23（下一整合候选）；模型包装M02不改。生产允许范围与继承/恢复约束以design根签为准，门柱补项只准Sites。保留4米采集/撤离、守卫条件、奖励、指挥点、费用、时间、协议和结算合同；不修改通用Field/Simulation/Unit，不加HUD或导航管理器，不改模型发布。官方1077/r2保持；1078历史证据不自动证明后续修改。最终Android完整流程、联机、性能及交付仍由整合任务独立验收。
