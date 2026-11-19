## Why
1050 安卓冷启动连续三次布局读取失败，手动重试才显示已保存的基地。

## What Changes
以冷启动直接恢复正确布局为验收目标，对照请求失败所处阶段，再决定传输调整。

## Capabilities
### New Capabilities
### Modified Capabilities
- `light-player-onboarding`：在线冷启动读取基地。

## Impact
M17 基地入口、档案读取以及安卓验收。
