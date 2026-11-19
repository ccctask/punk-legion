# Proposal

## Why

1076的a3/a4原生回防入口两次记录can_process离树ERROR。已签回防行为仍有效，但当前defense_alerts在pressed信号引发页面隐藏/重建时同步remove_child，存在仍处理GUI输入的按钮提前离树的明确源码路径，应在完整交付前修复该生命周期边界。

## What Changes

- 先以真实Viewport GUI鼠标输入验证现有警报场景的同步切屏路径，保留修前记录；不能用直接emit_signal假装重现GUI重入。
- 最小调整警报行退休/释放，使当前输入安全完成；保持点击一次只进入对应营地一次、立即失效的旧行不可再点击、后续新提醒正常重建。
- 专职测试代理验证源码层真实场景及必要Android受影响边界，复用未变的营地业务/费用/结算与换装证据；根签后才决定候选整合。

## Capabilities

### New Capabilities

无。

### Modified Capabilities

无规格行为变化。实现既有android-private-beta回防入口与工程生命周期安全要求，skip_specs=true；不为修复节点管理实现新增玩法条款。

## Impact

M23交付稳定性。生产范围优先仅game/camp/defense_alerts.gd；必要测试复用tests/godot的真实GUI输入、固定引擎与Job。当前1076/r2、冻结包/515源及现有测试记录保护不变。无新玩法/日程/网络协议/经济/数据迁移，也不把本修复当M06性能达标；无法定位可复验改进则保限制返回root，不扩成通用UI框架。
