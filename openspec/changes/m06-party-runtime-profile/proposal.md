# Proposal

## Why

1081 a1三人泵站在约340.83秒wall只推进270秒sim，完整终局仍未通过；目前没有同窗证据区分物理回调供给、Sim、存盘与同步。重复完整安卓场不能定位原因，先做一次有界真实服务诊断，服务当前完整可玩版出口。

## What Changes

- 主责M06，关联M04共享模拟、M15组队PvE与M23资源所有权；复用现有fd2f/b0eded镜像、正常API三新账号各6台12CP、真实ENet与既有OwnedJob/精确清理。
- 只为诊断保存Party物理回调、Sim.step、持久化、同步的同窗计数/耗时与wall、delta、sim推进；临时覆盖与原正式源严格分列，不改正式玩法或发布镜像。
- 先完成准确模块/权限/生命周期设计和定向资格，再一次Start后最多120wall秒诊断，结果指导一处后续优化；不足明确部分，不重复到绿。

## Capabilities

### New Capabilities

无。临时诊断工具，不新增游戏或持久化契约。

### Modified Capabilities

无。skip_specs=true，不造规格delta；原300sim、340peer、P95/覆盖门保持。

## Impact

允许本change verification下局部诊断覆盖件、消费报告与定向资格；资源入口若需改变M23 Owner，必须先准确AR并等待当前Repair76锁释放。没有Android/SDK/路由/collector操作权限、账号迁移、经济改动或完整终局信用；不恢复已撤销Field实验，不建设通用profiling框架，不修旧Linux M3工装。参见M06/root-current-pump1081-a1-result-review.md与相关原件。
