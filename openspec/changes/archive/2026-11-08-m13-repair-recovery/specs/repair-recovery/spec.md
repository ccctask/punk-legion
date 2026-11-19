## ADDED Requirements
### Requirement: Retained damaged robots and finite recovery
The service SHALL retain a defeated robot and its installed parts, prevent deployment while disabled, and support account-owned repair, voluntary recycling and bounded recovery.
#### Scenario: Repair across restart
- **WHEN** a disabled robot starts a paid repair and the owner reconnects after the due time
- **THEN** the same robot can deploy again, materials are charged once and workshop repair is distinguishable in its records.
#### Scenario: Insufficient resources and relief
- **WHEN** the account cannot field its minimum force and has exhausted ordinary resources
- **THEN** the player can recover a usable force through a limited nontransferable route, with no repeatable conversion of relief to profit.
#### Scenario: Voluntary recycling
- **WHEN** a player explicitly confirms an eligible idle asset for recycling
- **THEN** the transaction grants at most its stated conservative return, preserves historical identity and respects idempotency.
