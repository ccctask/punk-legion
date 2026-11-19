## Why

传输保持连接但服务端暂未推进时，画面可提前走到最后一个已确认位置。持续的履带声应该随实际移动停止。

## What Changes

核实并修复秘宝场景中持续停留同一权威 tick 时的移动音效，同步恢复后继续后续真实动作。

## Capabilities

### Modified Capabilities
- `treasure-battle-audio`：到达静止位置后结束循环声。

## Impact

客户端秘宝场景和持续移动提示。
