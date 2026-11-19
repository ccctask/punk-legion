# inventory-ledger Specification

## Purpose
为玩家保存有限资源、蓝图和实体部件，每次制造和出征都有可追溯的唯一回执。由权威房间记录并恢复战斗奖励，保证并发、重试和服务重启后每位参战玩家都只结算一次。

## Requirements

### Requirement: Atomic resource and inventory settlement
The service SHALL atomically track finite account resources, owned part instances, blueprint rights and a durable receipt for each manufacture, admission or reward transaction.
#### Scenario: Retried or interrupted business operation
- **WHEN** a completed transaction is requested again or an interrupted transaction resumes after restart
- **THEN** each effect is committed at most once, qualified retries can complete, and the original receipt identifies the resulting ledger entries.
#### Scenario: Insufficient stock or untrusted reward
- **WHEN** inputs are insufficient, the blueprint is unavailable, or an untrusted client supplies a battle reward
- **THEN** the caller receives no unauthorized item or balance change and any failed deduction is rolled back.
#### Scenario: Existing accounts
- **WHEN** a pre-inventory account logs in after upgrade
- **THEN** it retains its previous robot and receives its configured starter inventory exactly once.

