## ADDED Requirements
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
