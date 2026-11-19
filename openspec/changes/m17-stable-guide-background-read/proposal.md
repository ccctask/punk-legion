# Proposal

## Why

安卓运动验收遇到基地入口位置变化；静态GUI21秒观察稳定，而代码显示Guide每次后台GET均用短loading文字替换已加载内容，可无业务变化地改变滚动布局。先消除该明确表示层风险，再继续M23交付；不宣称已证实历史Android失败的唯一原因。

## What Changes

- 已加载Guide的后台请求期间保留Next/Daily文案；初载仍显示loading，Go请求期间仍禁用。
- 请求合并、权威成功更新、失败/401反馈保持原合同。
- 用最小真实GET夹具独立验证初载、后台同内容、排队重读及错误；不重新执行无关业务矩阵。

## Capabilities

### New Capabilities

无。

### Modified Capabilities

- `client-state-freshness`：增加已加载引导在后台读取期间保持内容布局的行为要求。

## Impact

主责M17 Guide表示，关联M11基地组合、M01自动读取、M23候选交付；生产仅game/onboarding/guide.gd::refresh两处赋值条件。测试复用现有GUI probe、Fixture与owned_run。无API/数据库/规则/新玩法变化，无数据迁移。若生产变更通过，发行必须新code/新源快照，不能覆盖或重签1085。
