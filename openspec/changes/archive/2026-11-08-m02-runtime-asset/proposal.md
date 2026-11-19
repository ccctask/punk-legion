## Why

联机样板需要登记过的可辨识真实机器人，复用现有履带机冻结版本，让客户端和后续实机性能检查使用相同资产。

## What Changes

引入一份小屏 GLB，包装朝向并提供变体与动作接口，制作独立样板场景。

## Capabilities

### New Capabilities
- `runtime-robot`: 冻结机器人在 Godot 中的展示。

## Impact

M02 的机器人消费部分依赖 M01 工程。场景地块、建筑与炮塔另行实施。
