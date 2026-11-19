# Proposal

状态：G2两文件切片6/6源码合同已签收，见verification/root-review.md；主责M07档案应用编排，关联M08/M10–M20/M24及M22。A01/G1已过；仅按design签收范围派实现，正式测试另门。

## Why

审计A03/A10发现，档案请求隐式提交八领域维护，再鉴权/执行业务；错误地拆开或合并会改变机体占用、库存与到期回执。先明确唯一应用编排所有者，并用新库行为证据固定提交/失败合同，约束后续功能不能在任意路由附加全域推进。

## What Changes

- 将现有八项维护序列收敛到显式应用入口，事务仍由请求应用层持有；保顺序、两个提交点、路由例外、到达摘要和本账号野袭时序。
- 明确该入口拥有编排、不拥有领域裁定；领域继续持有到期/结算不变量，不加Repository、注册框架或后台服务。
- 独立验证维护成功后动作拒绝、维护失败回滚、正常出征原子性与幂等、一条实际经济重入和一个只读例外；开发自测与正式测试分开。
- 保留全库扫描/锁成本及经济依赖环为未解决风险，不以提函数或通过合同测试宣称其消失。真正缩域另需完整参与者闭包及无请求推进责任。

## Capabilities

### New Capabilities

无。纯结构守恒重构，`.openspec.yaml`设置`skip_specs: true`，不为内部提取发明玩家能力。

### Modified Capabilities

无。沿用inventory-ledger、player-persistence与engineering-baseline既有合同，不改变费用、资格、奖励、权限、失败语义或数据格式。历史规格中的升级/恢复场景不授权本轮迁移；仅本轮新库及当前schema夹具。

## Impact

候选生产范围为`services/profile/server.py`及一个薄应用编排模块；实际文件名/入口在design与最终AR确定。静态依据为[原边界调查](../../../../build/architecture-review/a03-a10-readonly.md)、[三个请求切片](../../../../build/architecture-review/a03-g2-slice-input.md)，真实server c88、onboarding90432a、expedition226931。本轮不改领域SQL/到期条件、HTTP/RPC/账目/spool、Godot/模型或当前1077/r2部署，不承诺性能改善。
