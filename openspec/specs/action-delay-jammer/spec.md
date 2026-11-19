# action-delay-jammer Specification

## Purpose
规定干扰器如何延迟敌机武器与维修动作、保护期如何生效，以及移动和重连时的战场行为。权威房间负责判定动作生效时刻，并在队员重新进入后同步当前状态。

## Requirements

### Requirement: Protected next-action delay
The server SHALL permit normal movement during disruption, delay the next pending weapon and repair actions individually, and enforce one protection interval per target across all sources.

#### Scenario: Simultaneous emitters and moving target
- **WHEN** two allied emitters hit the same moving target with pending weapon and repair actions in one tick
- **THEN** the target continues moving, each pending action is delayed once, and the target shares one protection interval across both emitters.

#### Scenario: Reconnect during protection
- **WHEN** a client rejoins the same battle before protection expires
- **THEN** the restored target retains the original deadlines and protection interval without replaying the pulse or adding a career statistic.

#### Scenario: Idle repair tool
- **WHEN** no ally requires repair until after the temporary disruption expires
- **THEN** the repair tool follows its ordinary schedule without a saved disruption penalty.
