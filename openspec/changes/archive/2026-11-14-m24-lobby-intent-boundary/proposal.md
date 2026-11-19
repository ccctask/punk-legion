# Proposal

## Why

审计A05发现秘宝大厅读取失败后仍可自动发出点击时缓存的写请求；旧页面回调和初始无有效视图也缺少明确边界。负责人要求架构整改先行，本项先修M24大厅意图与请求生命周期，保留服务最终裁决。

## What Changes

- 以局部意图组件承载create/select/confirm/cancel的精确请求体、相关可见上下文和刷新后复核；失败读取/失效上下文/离页/admission清未发意图。
- 成功读取只在该操作相关上下文仍有效时消费一次原意图；无关显示变化及队友正常确认推进不误伤合法操作，单人与双人确认分别处理。
- 页面拥有请求实例/代次与关闭状态；关闭先失效再发closed，旧回调不能清新请求状态或发幽灵写。未知已发POST以读取当前事实核对，不自动重发。
- 初始/无效视图禁写，失效意图要求重新核对；实际场景输入/HTTP及新库小型集成独立验收。

## Capabilities

### New Capabilities

无。

### Modified Capabilities

- `contested-treasure`：增加大厅意图有效性、读取失败、未知写及离页/旧回调的可观察合同。

## Impact

主责M24，关联M05权威边界及M15队伍语义但不改其实现。允许game/treasure大厅脚本/必要控件及局部纯策略、对应测试文档；服务treasure/workshop/inventory只读作契约与集成依据。当前入口game/treasure/treasure.gd SHA c1bb34ef2e9febda055177787d0e631806295b88455582012b6f074e91d783f6，scene 71d2c7fd3a91eb8c28db4dac2746961c4363051e7a2505565fa90046a1b2c4d7，服务treasure.py 76cf16b1ba87e09e32a7dd286b6afa0d65ea883aa521412a869cb74267ef54a2。

复用现有treasure.tscn/7秒HTTPRequest配置、队伍版本/装配校验与账本及已验GUT/HTTP夹具能力；不新增全局RequestManager、不改服务协议/事务、战斗规则、预算、奖励、持久格式或正式1077/r2，不构建APK或执行迁移。结构与失败合同由design评审签后再派实现。
