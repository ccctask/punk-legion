## Why
1057 正常建成的配电柱进入野袭冻结布局后，Godot 在 HTTP 200 时误报战况格式错误，阻断预警和回放。
## What Changes
- 冻结布局校验接受服务器提供的全部合法建筑，保持非法种类和破损字段拒收。
## Capabilities
### Modified Capabilities
- wild-base-raids
## Impact
Godot 私人基地防守入口，正常配电柱布局、权威战况与回放显示。与登录传输对照独立。
