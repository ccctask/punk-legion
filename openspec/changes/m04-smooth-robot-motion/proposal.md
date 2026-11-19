## Why

负责人试玩发现探索机器人行走顿挫、拐弯折线，希望研究赛车式轻微惯性，并于2026-11-18明确要求按Godot技术方案处理。自动状态更新现已由M01归档并发布1084；运动以该客户端源为基线独立评审，不能把未经诊断的卡顿一律归因寻路，也不能直接改战斗朝向和碰撞规则。

## What Changes

- 原研究及Godot专项方案已完成；2026-11-18负责人明确开始研发，本轮进入标准Solo探索的自然Godot基线与网络呈现首个实现切片。
- 区分20Hz模拟、稀疏网络位置样本、追最新点呈现、动画／瞬转、四邻域路径和恒速推进。
- 提出快照呈现／安全路径跟随／权威轻惯性的递进方案，保已签净空、盾向、指令、检查点及重规划预算。
- 先为自然Solo ENet/渲染观察工具签具体架构评审，由开发实现、独立测试获取基线；据实际样本锁缓冲参数和标准Solo静态净空合同，再单独签网络显示组件的实施评审。首个实现切片不改变服务器实际路径/速度/盾向。
- 补齐Godot4.6.1官方API、当前真实调用链及场景组合方案：明确物理插值与网络插值的区别、现有AStarGrid2D与实际动态搜索的关系，以及NavigationAgent3D/VehicleBody3D的取舍。具体依据见research/godot-technical-review.md，独立测试选集见research/godot-test-plan.md。

## Capabilities

### New Capabilities

robot-motion-continuity：标准Solo探索的网络显示连续性、实例生命周期、保守静态净空与本地直通；无样本时不无限外推，生命/死亡与指令仍即时权威。

### Modified Capabilities

无既有业务规则变更。安全路径转弯与权威惯性继续属于下一独立实现评审，不在本轮网络显示切片内暗改。

## Impact

M04主责，关联M05/M14及共享Unit的本地演练消费者。代码候选为battle/motion_track.gd/.tscn、battle/unit.gd/.tscn和expedition/expedition.gd；具体获准清单以各实施AR为准。已有测试框架/OwnedJob优先复用，仅加必要诊断/回归入口；测试工具同样先AR。首期标准Solo显式启用，party/pump/factory/armory/camp/treasure及本地battle默认保持旧行为。无经济、服务器协议、权威路径/速度/检查点变更，无迁移。1084包、当前索引、R2与手机保持；Godot研发结果与后续Android/发布分门，不声称新P95。
