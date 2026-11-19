## ADDED Requirements

### Requirement: Recover an uncertain owned refit in place
The workshop SHALL visibly recover an interrupted single-part refit at its point of use using the persisted operation identity and a bounded automatic retry.

#### Scenario: Lost committed response
- **WHEN** the server installs an item but the first response is lost
- **THEN** the garage recovers the original receipt and authoritative fit without further player action or a second transaction.

#### Scenario: Repeated interruptions and initial read
- **WHEN** automatic recovery for a refit or the initial garage read is exhausted
- **THEN** the affected screen shows a reachable retry, retains any uncertain operation, and does not imply that stale or missing data is current.
