## MODIFIED Requirements

### Requirement: Settle a camp battle at its time limit
The camp room and profile SHALL use a consistent terminal timestamp for regulation play and settle previously persisted valid timeout results affected by numeric rounding.
#### Scenario: Live camp reaches regulation time
- **WHEN** an authoritative camp simulation with surviving damaged robots reaches the 180-second limit
- **THEN** both sides receive the authoritative contest result and the single ownership and damage outcome releases the original sortie assignments.
#### Scenario: Recover the prior room result
- **WHEN** a previously stored legitimate 1010 timeout result is drained or redelivered
- **THEN** its original contest reaches the same terminal state once, with strict validation of materially invalid reports.
