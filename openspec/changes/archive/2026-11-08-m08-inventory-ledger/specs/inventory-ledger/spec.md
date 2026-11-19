## ADDED Requirements
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
