# Proposal

## Why

秘宝争夺是已确认的公开多人玩法。当前1077客户端与r2后端有历史主验，但交付审计明确未核清后续treasure/treasure_combat/UI改动对个人结算、机体累计与归还的影响，不能据旧五客户端通过就认定当前链完整。

## What Changes

- 以当前冻结客户端和r2实际有效服务源为对象，逐项判读M24原验收的依赖、历史原始证据与后续差异；列出可继承、受影响、证据不足的断言。
- 优先收口个人预算/确认、争抢与携货、个人终局/唯一流水、战损归还及参战/击败/施修累计，不新增玩法或详细机体日志。
- 只有依赖变化实际影响且无充分现成证据的场景才追加最小新数据回归。测试代理先交选集与真实入口，root审后单独放行；主代理不重复跑测试。
- 将当前可用范围和剩余缺口同步现有文档/进度页，避免25模块全量重验。

## Capabilities

### New Capabilities

无。

### Modified Capabilities

无。遵循现有contested-treasure及robot-service-record，不改变规范行为；本项是交付证据与按需回归工具，skip_specs=true。发现产品缺陷时交root决定最小修复及必要实现派单，不能靠改断言掩盖。

## Impact

模块M24，关联M03/M05/M08/M10/M13/M20。只读核当前`build/private-beta/current-playable.json`、rc1077源清单、r2有效服务源与既有秘宝主验；重点services/profile/treasure.py、treasure_combat.py、service_record.py及game/treasure客户端/房间链。证据写本change verification，长期入口docs/testing及docs/contested-treasure.md，进度代理维护原页。当前试玩、签名包、六服与health/operator台账不改，不迁移、不回放旧版本战报。
