# Proposal

## Why

当前候选工坊的按钮吞掉拖动事件，下拉框在按下时立即弹菜单，阻断移动端滚动浏览。M23的[三起点真实GUI诊断](../m23-architecture-release-integration/verification/root-workshop-scroll-diagnostic-a2-result-review.md)已复现；必须先修此主干入口，再完成经营与安卓整包验收。

## What Changes

- 只配置工坊滚动内容中明确白名单的静态Button/CheckButton为PASS；OptionButton同时使用RELEASE，复用原生滚动取消机制。
- 保留短点、选择、禁用、输入框编辑及业务提交，做最小真实GUI正例，再交M23候选与Android玩家链。
- 不新增玩法、输入管理器、手势脚本、网络规则、资产或数据迁移。

## Capabilities

### New Capabilities

无。

### Modified Capabilities

- `owned-workshop`：工坊滚动内容的按钮/选项能从原控件上拖动浏览，拖动不产生点击/选择，短点保留原功能。

## Impact

主责M09，关联M00输入基线/M23内测。生产仅`game/owned/workshop.tscn`明确直接节点属性；不修改原M00排除工坊的历史许可。测试复用既有probe/OwnedJob，工具适配须另经根审；服务镜像/数据协议不变。现1077/r2保持至M23完整交付，不据桌面结果签Android通过。
