## ADDED Requirements
### Requirement: Shared authoritative squad battle
The room SHALL run one shared battle after both seats are ready, simulate owned squad commands on the server, and deliver a single authoritative outcome.
#### Scenario: Two commanders fight together
- **WHEN** two ready seats join and issue movement or focus orders
- **THEN** both clients observe the same battle, ownership, unit health, and final result.
#### Scenario: Resume battle
- **WHEN** a retained seat reconnects before its grace period expires
- **THEN** it receives the current battle or its retained final result with the same battle ID.
#### Scenario: Command validation
- **WHEN** a seat sends repeated or foreign-unit commands
- **THEN** the server preserves the accepted orders and ownership.
