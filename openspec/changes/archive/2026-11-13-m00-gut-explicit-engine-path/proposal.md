# Proposal

## Why

M00已验收的GUT快速回归入口硬编码旧引擎路径，当前文件不存在；同版、同SHA引擎存在于Codex LocalCache。恢复该入口，才能用快速选集代替反复准备安卓环境检查规则与场景，服务当前内测试玩主干。

## What Changes

- prepare/run接受显式引擎路径，保留原默认值及固定SHA校验；在创建工作区、启动引擎之前明确拒绝缺失或错误二进制。
- 新工作区记录实际引擎来源，run核对该工作区的引擎身份，不自动查找、安装或降级。
- 更新测试入口说明，由开发代理实现/自测，test_lead独立定向验收，root审查；不重复既有完整冷暖、负控或安卓矩阵。

## Capabilities

### New Capabilities

无。

### Modified Capabilities

无；纯测试工具环境修订，沿用engineering-baseline的既有选集、证据与资源要求，skip_specs=true。

## Impact

仅tests/godot/run.py、tests/godot/README.md和本轮测试文档/证据；不改生产源码、依赖锁、GUT测试断言、冻结1076、APK、服务或游戏参数。无数据迁移、无新数据库/模拟器/容器。待决问题：无；轻量工具修订按用户既有自主委派授权推进。
