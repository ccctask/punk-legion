# Proposal

## Why

完整可玩版仍缺有效的新整合候选帧预算证据。原正常游戏采集链有效，但每次命令后固定休眠0.4秒、没有低频所需的历史容量/连续重叠守卫；旧独立QA回放三次未ready且已停止，不应再为采集另造包。

## What Changes

- 复用正常游戏capture/analyze/Clock和r2全场global/tail合同，在测试侧添加显式查询节拍与ring资格、在线/离线同规则守卫。
- 新候选实际运行以单独根签/锁为准，不重开旧QA启动路线、不重复动画候选或制造游戏性能优化。
- 完整保留真实慢帧和全场分母；低频结果只判断实际候选在该采集条件下是否达原33.333ms预算，不声称查询因果效应或零探针性能。

## Capabilities

### New Capabilities

无。

### Modified Capabilities

无。仅测试工具内部适配，device-battle-baseline和engineering-baseline要求不变，skip_specs=true。

## Impact

主责M06，M23消费实际候选测量结果。实现仅本change verification/tools和独立QA目录；不改游戏/服务/资产/正式包/旧工具与原件。依据[真实只读评审附录](../../../build/architecture-review/m06-next-performance-slice-input.md#附录root决定停止a后复用正式游戏的低频sf实际呈现口径)。root先审边界，开发实现/必要自检，test_lead独立工具资格及正式测量/清理，进度代理原页维护。运行门不由提案自动授予；无迁移，最终场次从新库新号生成。
