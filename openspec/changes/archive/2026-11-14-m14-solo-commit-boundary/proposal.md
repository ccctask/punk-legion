# Proposal

## Why

审计A01发现单人房间在保存返回false后仍可确认命令，tick/join/断线/终局又有其它发布入口。架构整改G1需要先明确内存、检查点、终局文件和权威收据的提交边界，避免只加一个if而从别的路径发布未保存状态。

## What Changes

- 为Solo持有的单人任务建立保存失败后的发布屏障、原状态重试与恢复合同，不重执行原命令。
- 终局文件优先于旧检查点，保持原payload；明确部分提交、到期收据冲突和合法重连收敛。
- 保留party/camp继承、既有RPC/存档格式和服务账务；针对实际失败路径独立验收，不全盘重写网络。

## Capabilities

### New Capabilities

无。

### Modified Capabilities

- `solo-expedition`：增加保存失败时的命令确认/状态发布及不可变终局交付合同；既有单人/重连/唯一结算规则继续有效。

## Impact

主责M14，关联M05/M07/M08，继承影响检查M15/M19。当前生产拟仅改`game/net/solo.gd`，复用Mission、原_save及outbox/open/settle，不改共享保存语义、派生玩法/客户端页面、协议、服务、经济规则、部署或当前1077包。源事实与限定方案见[只读输入](../../../../build/architecture-review/a01-solo-readonly.md)。本提案不授权数据迁移，也不授权在A05源锁未释放前改变其依赖。实际实现须主代理完成AR及测试代理选集；范围扩大退回评审。
