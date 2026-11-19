# Proposal

## Why

M06一次新库三席泵房观察在正常大厅出发前读取耗尽，手动刷新一次仍失败，未生成mission。现有日志不能区分请求启动、传输、HTTP、JSON及快照校验，盲改会破坏已验收的恢复边界；先取得请求级证据，恢复有限试玩主干的真实前置。

## What Changes

- 仅从冻结1076派生诊断副本，在expedition.gd和隔离profile server.py增加脱敏请求级元数据；保留所有原业务分支、校验、重试、计时及连接行为。
- 复用M09单脚本字节码/端点/索引局部派生及M06设备/新库/收尾工具，使用已有debug key；不发布新试玩或建设通用追踪平台。
- 专职测试代理执行一次新库三新号同规模待发观察；先确认双端标记可收，再最多一次普通手动刷新，停止于故障或有界截止，不出征、不启动战斗peer或性能采样。

## Capabilities

### New Capabilities

无。

### Modified Capabilities

无；诊断工具与冻结副本观测，不改变生效玩法/工程要求，skip_specs=true。

## Impact

M15正常大厅为M06整场性能验收前置。代码改动仅在本change verification诊断工具/生成副本及build/diagnostics输出；生产game、services、正式1076/APK/冻结源/签名材料不变。test_lead维护测试文档，root独立审查，进度代理引用；不迁移旧数据。产品修复须根据实际证据另立任务，不能把诊断结束当作故障修复或性能通过。无待决产品问题，按用户既有自主委派授权推进。
