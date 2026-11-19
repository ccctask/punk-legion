## Why
主代理以实际模拟器测试期间创建的首版 v7 数据库重启，所有档案请求返回 503。数据库 raid_clocks 当时没有之后新增的 await_owner 字段。
## What Changes
新增显式版本迁移，支持带或不带等待玩家返回字段的两种 v7 库。保留账号进度、冻结布局、已发生损失和离线保护。
## Capabilities
### Modified Capabilities
- `wild-base-raids`：兼容现有真实开发存档。
## Impact
档案启动迁移、备份恢复、验收夹具及文档。
