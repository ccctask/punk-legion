# Proposal

状态：G3/A06/A07/A11，7/7；design末a3独立六组已限定根签，已归档并签归档静审，未整合1077/r2。主责M14探索页面生命周期，关联M15/派生探索、M05会话、M11基地与M18世界地图组合根。

## Why

现有探索tscn已组合多份独立视图，但宿主仍隐式查找/root/Solo与/root/Party，不能在明确提供依赖的上下文独立复用。五个关闭出口先发closed、后在延迟释放时收尾，存在旧回调/旧页断开新页复用会话的静态顺序风险，尚未声称已复现玩家故障。

## What Changes

- 保留现有场景与Solo/Party，由基地及世界地图实际探索入口在入树前显式提供既有会话；缺配置可诊断、安全返回，不隐式回退全局查找。
- 统一宿主局部幂等收尾：页面及HTTP回调先失效，断自己的changed订阅并释放当前mission连接，再发关闭信号；直接移除由_exit_tree同一收尾兜底。
- 保留Factory/Pump/Armory派生钩子、路由/body、匹配取消/未知POST恢复与现有网络权威；独立验证实际组合入口、真实HTTPRequest关闭和同步重开。

## Capabilities

### New Capabilities

无。实现既有engineering-baseline的明确初始化/释放与缺配置诊断、party-expedition的关闭后停止读取/失效意图合同，不新增产品能力，skip_specs=true。

### Modified Capabilities

无规格级行为变化。关闭仅放弃本地请求观察，不表示服务端撤销或结算改变；不发明主规格来满足校验。

## Impact

候选生产仅game/expedition/expedition.gd、game/base/base.gd、game/world/world.gd。不新增管理器/通用HTTP层，不修改tscn、三个派生脚本、Solo/Party、服务端、战斗/资源/费用/持久格式或当前1077/r2。测试路径/真实选集由test_lead预选、root最终AR后固定。旧直接性能/美术bench不提供入树前依赖，登记待按使用适配，不为兼容它们恢复全局回退或重开采样。

依据：[G3只读输入](../../../../build/architecture-review/g3-final-review-input.md)、[架构整改台账](../../../../docs/architecture-remediation.md)G2限定出口。所有测试数据本轮新生成，无迁移；开发自测、独立测试、根签与实际试玩版本分别登记。
