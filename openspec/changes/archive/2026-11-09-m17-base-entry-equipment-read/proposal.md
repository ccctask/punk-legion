## Why
1023 安卓两次登陆出现首机装配同步失败，需玩家手动重试才能返回私人基地。基地是常规启动入口，已派遣多台机体的玩家也应能正常进入。
## What Changes
复现正常首机和满编派遣状态下的基地读取，识别失败层级，修正能证实的问题并回归错误恢复。
## Capabilities
### Modified Capabilities
- light-player-onboarding
## Impact
M17 基地启动、M07 档案与安卓入口验收。
