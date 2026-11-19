# Proposal

## Why

1082 a2真实合作在cache近距已满足、敌清空时仍等到300秒超时：客户端长期seq4、终局才seq5，未发cache Collect。源码存在明确进度窗口：Party成功Route仅发完整帧，继承客户端可因较新delta的elapsed而整帧丢弃命令号；本轮无收包判定日志，不把它写成唯一实场根因。

## What Changes

- M15合作房间对已成功持久提交的move/route复用现有可靠ACK，保原完整帧及位置防回退。
- 先以实际当前客户端/ENet验证过时全帧与新delta交错下序号可见、位置不退；失败与未知提交不报成功。
- M23准备仅服务端修订，RPC声明及客户端代码不变时优先复用已签1082 APK；实际兼容与当前组合仍须验证。

## Capabilities

### New Capabilities

无。

### Modified Capabilities

- `party-expedition`：已持久提交的个人移动指令确认独立于位置快照时序。

## Impact

主责M15，关联M05权威发布、M14既有继承ACK、M06整场验证和M23组合交付。仅game/net/party.gd::_order成功保存后的move/route发布；不改Solo客户端、模拟/身体/目标条件、费用、存档格式、RPC签名、测试等待门或关卡，不做迁移、不重投旧战报。当前完整安卓交付阻塞缺口内的正确性修复，不增加玩法范围。
