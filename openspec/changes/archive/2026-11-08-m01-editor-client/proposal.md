## Why

双窗口是 PunkLegion 首个可重复复测的客户端入口。两个玩家需要从同一工程进入本机服务端、辨认各自单位并通过点地指挥检查权威移动状态。

## What Changes

交付 M01 的桌面调试入口、共享房间状态展示与 Android 横屏触控配置。依赖 M00 的场景规范、M05 房间契约及 M02 模型包装。

## Capabilities

### New Capabilities
- editor-client: 编辑器双实例连接、移动和重连。

## Impact

变更 Godot 工程配置与客户端场景。首轮参数采用 127.0.0.1:24567，Android 可填写电脑局域网地址。
