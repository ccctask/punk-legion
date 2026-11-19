# Proposal

## Why

M06当前整场P95 77.455ms未达33.333ms，已签离线数据表明外部操作墙钟覆盖24.6%，但不足证明采样因果。先检验额外密集SF查询在相同动态画面下的扰动，减少后续归因和优化的观测偏差。

## What Changes

- 在锁定rc1076副本添加独立本地动态回放入口，使用本轮当前规则新生成的三席夹具，不连接业务服务。
- 复用现有采集与进程归属工具，对共同低频SF观测保持一致，只切换额外查询；执行一次ABBA/BAAB有界对照，保留全部帧及失败。
- 分离开发自测、测试代理准备/实际执行与root签收，报告工具资格及限制，不宣布游戏性能通过。

## Capabilities

### New Capabilities

无。

### Modified Capabilities

无。仅M06诊断工具及测试记录，device-battle-baseline和engineering-baseline行为要求不变；skip_specs=true。

## Impact

实现限本change verification与全新build/qa副本；正式game、515冻结源、1076 APK、当前六服及稳定运行配置不改。最多一独立诊断APK、一AVD、一客户端，零新服务/数据库/容器/陪测端。无迁移，不重投旧版本战报。依据[已签下一范围](../archive/2026-11-13-m06-pump-attribution-preflight/verification/next-measurement-scope.md)；开发制作、test_lead正式执行与清理，root只规划/审签，进度代理维护原页。
