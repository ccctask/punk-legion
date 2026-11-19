## ADDED Requirements
### Requirement: 泵房固定地标采用可编辑的 Godot 场景组合
泵房客户端 SHALL 在 Godot 场景层级中定义两阀、箱与出口的固定节点并使其与服务端交互位置相符。
#### Scenario: 载入泵房
- **WHEN** 编辑或运行泵房战场
- **THEN** 可在场景结构定位四个有名地标，运行时各自绑定对应外观、交互位置及状态。
