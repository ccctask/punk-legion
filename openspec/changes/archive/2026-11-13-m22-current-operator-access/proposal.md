# Proposal

## Why

交付审计确认现行M22要求的受限场次诊断/单次补偿尚无当前可操作准入，健康监控不能替代它。已有operations.py及历史验收，但真正只读部署会因权限/路由判断晚于写事务而先报SQLite错误，需修复并提供当前可用的最小操作入口。

## What Changes

- 将既有运维接口的路由/角色拒绝移到写事务之前，保持鉴权、补偿1–3单位、业务键幂等、重复拒绝及审计语义。
- 交付按需启动、调用后必清理的本机工具与两种sidecar准入：viewer诊断挂当前DB目录RO；compensator补偿挂当前DB目录RW。两者policy各只含对应角色、四队列RO、无主机端口/外部网络，不常驻运维服务。
- 使用独立随机凭据、SHA策略及当前Windows用户DPAPI密文；不触签名vault，不把token放argv/env/日志。工具提交前保存无秘密的业务键/参数指纹，未知结果原样保留且不自动重发。
- 独立新库/新号/本轮incident验证真实补偿与拒绝/幂等；当前真实环境只做不写入的准入/诊断检查，正式补偿能力可操作但不向现有玩家发补偿。

## Capabilities

### New Capabilities

无。为既有要求交付运维工具和实现修复，`skip_specs: true`。

### Modified Capabilities

无。沿用`economy-and-operations`的可定位异常、受限单次补偿和脱敏要求；不新增公网API、自动补偿或迁移行为。

## Impact

模块M22当前运维出口/M23交付。涉及services/profile/operations.py、专用tools/operations工具、稳定operations/1077-operator-r1配置/维护和文档。原r2六服务、health常驻实例、四份r2 Ops及health实际配置、正式1077 APK/515冻结源不改不重建。新运维sidecar复用固定profile镜像与实际c88 server覆源，并单独绑定新ops代码；不能把它混称原六服源码已更新。无旧库导入、数据迁移、恢复/回退演练或新常驻后台，不关闭M06和其它H/U/E/L出口。
