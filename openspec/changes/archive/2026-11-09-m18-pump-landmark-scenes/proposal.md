## Why
泵房关卡已有独立 Godot 场景，但四个固定目标、名称牌和显示位置都在 field.gd 的 _ready 中逐个新建。固定布局应能在编辑器中查看，后面替换 Blender 模型时也能只更新对应地标。
## What Changes
将西阀、东阀、物资箱、出口建为可编辑的场景节点或子场景。按原资源库方式绑定发布网格，复用已有模型及其材质。明确权威交互点与场景位置的自动对照。
## Capabilities
### Modified Capabilities
- cooperative-ruins
## Impact
M18 Godot 客户端泵房场景及验收；已验证服务端玩法继续使用。
