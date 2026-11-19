# player-persistence Specification

## Purpose
为每个测试账户持续保存机器人身份、命名和独占任务。服务端在会话轮换、并发指派、容器重启和备份恢复后保持归属及任务的一致性。

## Requirements

### Requirement: Persistent player identity and robot assignments
The service SHALL persist account-owned robot identities, names and task states across restarts and authorize mutations using the active account session.
#### Scenario: Restart and restore
- **WHEN** a player signs back in after a restart or a tested backup restore
- **THEN** the same robots and tasks reappear, and unsupported data versions are explicitly rejected.
#### Scenario: Conflicting assignment
- **WHEN** a robot is assigned overlapping expedition, guard, aid or repair tasks
- **THEN** at most one succeeds and the losing request leaves no partial change.
#### Scenario: Session replacement and isolation
- **WHEN** an old session or another account attempts to update an owned robot
- **THEN** data remains unchanged.

