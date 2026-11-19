## ADDED Requirements

### Requirement: Bounded facility downtime and recovery after a breach
The private raid SHALL persist at most one damaged production facility on defeat, show its identity, repair price and recovery time, and exclude only that facility from productive operation until it recovers. The service SHALL cap raid loot plus quoted robot and facility repairs at four resource units.

#### Scenario: Repair a breached facility
- **WHEN** the owner returns after defeat and repairs the affected workshop or foundry for one structure
- **THEN** the base identifies the location and restores operation when powered, existing output is retained, and repeated repair submissions cannot charge twice.

#### Scenario: Offline recovery
- **WHEN** the owner remains offline past the ten-minute downtime and later claims production
- **THEN** production credits eligible time before and after downtime under the usual caps, unaffected facilities continue, and the owner owes no fee for natural recovery.

#### Scenario: No eligible building
- **WHEN** a raid succeeds defensively or no eligible facility exists
- **THEN** no facility is stopped or repair fee quoted.
