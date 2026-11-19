# Proposal

状态：G2/A04当前能力补证与两端移动冷却修复已限定根签；GD a3/Python a4五组组合通过，归档收尾。主责M04动作模拟，关联M09部件能力、M14模型检查点、M24独立战斗实现、M10实际输出归属及M00测试工程。

## Why

目录与装配已签，但当前Godot的lock截止、Python的aim截止及检查点字段相对旧干扰主验发生了直接相关变化，旧绿灯不足以证明下一动作延后与恢复。[逐断言证据](../../../../build/architecture-review/a04-capability-evidence-input.md)已确认可复用的账目/局部算法边界；本案只补当前受影响行为，避免重复整场测试。

## What Changes

- 复用现有jammer/repair/weapon对照组织，建立当前两端纯逻辑小选集：自然锁定、实际冷却中移动、空闲维修及同轮模型恢复，顺带有效量配对和3米/4米武器职责。
- 保真实生产step/动作/检查点入口及连续事件，禁止预填被测截止、保护或事件制造通过；移动中真实pending场景不得按实现条件删掉。
- 复用既有OwnedJob、最小隔离源/原件报告，正式执行前锁候选和新门；发现产品失败保原、回到根AR后才修生产。
- 修正已实测Godot移动时仍有未来武器冷却，却被判为没有待执行武器动作的问题；延用原自然冷却与锁定截止，不改干扰1秒/保护4秒或移动规则。原失败与未运行范围见[独立a2根审](verification/root-independent-a2-review.md)。

## Capabilities

### New Capabilities

无。测试补证现有动作合同，skip_specs=true。

### Modified Capabilities

无。沿用action-delay-jammer、field-repair-module、rivet-repeater、robot-service-record及engineering-baseline，不改变玩法、数值、费用、累计或权限。若发现实现违反现行要求，先由主代理明确缺陷及允许修订，不把不支持的场景改写成通过。

## Impact

允许生产范围为game/battle/simulation.gd的_jam与a3已实测确认的services/profile/treasure_combat.py的disrupt待武器截止判定；具体分次范围以design末AR为准。工具/断言冻结，当前1077/r2不变。无HTTP/DB/账号/ENet/Android/容器/迁移；M24旧账目需按该修订重新审依赖后才继承，不冒称当前新HTTP执行或各模拟逐帧等价。
