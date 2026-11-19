# Proposal

## Why

M15唯一诊断复现三席泵房大厅读取耗尽：14条GET客户端result2/零字节，与同标签服务200及write返回并存。普通M06无插桩包也曾停在相同入口，阻断整场性能验收；需验证受限响应交付改善，不能继续堆重试或放宽快照保护。

## What Changes

- 将共用合作大厅的成功GET /v1/party、/v1/pump、/v1/factory加入现有6秒闲置保活白名单，仅扩路由判定一处。
- 保留HTTP1.0/显式close/非200/错误定界的关闭和逐请求认证，原写路由/费用/客户端逻辑不变。
- 独立测试真实TCP边界及一次无插桩安卓三席大厅；复用已验证的1076仅端点诊断包，不再编译或签名，不重跑无关GUT或原生故障全矩阵。

## Capabilities

### New Capabilities

无。

### Modified Capabilities

- `android-private-beta`：新增成功合作大厅读取的有界响应交付及保活边界要求，不替代已有大厅恢复、工坊交付或签名整合规格。

## Impact

M15/M06前置。生产改动仅services/profile/server.py白名单，当前容器/1076 APK/冻结源/签名材料不改；本轮为候选验证，发布整合另行验收。开发代理实现，test_lead独立执行，root签收，进度代理同步；从新库/新卷/新号开始，不迁移。采用有限措施不等于证明底层TCP/Android/Godot根因已消除。
