## Why

负责人把机体战斗日志收敛为累计值。逐场时间线与收藏高光增加查阅和存储成本，玩家关心这台机体参战、击败及实际维修的总量。

## What Changes

玩家机体档案仅记录并显示累计参战场数、击败敌机数、实际为友机恢复的耐久值。结算以机体身份幂等记账，保留正常玩法的回执和战损处理。

## Capabilities

### Modified Capabilities
- `robot-service-record`：机体三项服役累计与收藏。
- `field-repair-module`、`action-delay-jammer`、`playable-chassis-choice`：战斗动作与换装按机体身份归属。
- `editor-client`、`private-campaign-acceptance`、`solo-expedition`、`party-expedition`、`live-camp-contest`、`android-private-beta`：保留玩法结算与移动端入口，用三项累计核对个人贡献。

## Impact

档案服务、Godot 机体面板、策划与生效规范。开发验收从新库开始。
