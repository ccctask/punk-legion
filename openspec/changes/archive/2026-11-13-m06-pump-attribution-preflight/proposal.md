# Proposal

## Why

已签当前三席整场P95为77.455ms，M06预算未达；现有数据不足以把慢帧归因GPU、机体或宿主。旧参数方向多次未达门槛，应先利用现有248秒原始记录缩小下一次测量问题，减少重复起服、打包和实战。

## What Changes

- 增加一次有锁输入的离线分析：复用原SF帧对/时钟与完整分母，重现原7368间隔分布后，描述主机总CPU/可用内存、采样调用和可见性检查/截图/输入操作时间窗与慢帧的关联。
- 显式保留61.476ms时钟不确定性，将关联分为确定重叠、确定不重叠及不确定；不删除慢帧、重算“优化后FPS”或宣称因果。
- 对现有client_phase_probe/instrument_client的当前源码适配点作具体复用审查，明确旧GPU全零证据和时间段的含义，由root选定下一项有界实际测量。

## Capabilities

### New Capabilities

无。

### Modified Capabilities

无。落实device-battle-baseline与engineering-baseline的取证/分工要求，不变更玩法、预算、机体、画质或发布行为；skip_specs=true。

## Impact

M06性能取证工具与文档，输出仅本change及独立build/qa目录。当前1076 APK、515冻结源、1076-delivery-r2六服/数据/配置保持；本次不启动Godot/AVD/容器，不打包签名、访问业务服务、导入数据库或执行迁移。开发子代理实现/必要纯自测，test_lead独立离线运行，root只审查及确定后续范围，进度代理记录必要性与缺口。
