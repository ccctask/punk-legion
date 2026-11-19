## ADDED Requirements
### Requirement: Persistent private buildable territory
The server SHALL maintain a separate private grid for each account and validate placement, movement, necessary access paths and power connections.
#### Scenario: Build and reopen
- **WHEN** an owner places or moves a core, producer, warehouse, workshop, repair facility or fixed turret and signs in again
- **THEN** the saved buildings, footprints, roads and power state match the accepted layout.
#### Scenario: Invalid or conflicting change
- **WHEN** a change overlaps a building, crosses the grid boundary, seals necessary access or is stale
- **THEN** the owner sees a reason and the last accepted layout and costs are retained.
#### Scenario: Frozen defense layout
- **WHEN** defense captures a layout revision and the owner changes their base afterwards
- **THEN** the captured buildings and positions remain fixed for that defense while subsequent snapshots see the new revision.
