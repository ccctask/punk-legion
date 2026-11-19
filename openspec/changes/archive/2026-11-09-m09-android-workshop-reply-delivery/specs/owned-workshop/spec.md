## ADDED Requirements

### Requirement: Deliver complete workshop replies to the signed mobile client
The supported local Android release path SHALL deliver an authoritative garage snapshot and the original refit receipt after a single interrupted committed reply, without requiring a new item installation.

#### Scenario: Android garage receiving a full replay
- **WHEN** the original committed refit reply is cut and the next request presents the same key
- **THEN** the signed Android garage shows the verified authoritative fit without manual retry and the ledger retains one installation.
