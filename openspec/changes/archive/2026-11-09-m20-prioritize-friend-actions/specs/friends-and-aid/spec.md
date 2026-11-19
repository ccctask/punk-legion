## ADDED Requirements
### Requirement: Friends actions take precedence over automatic reads
The friends UI SHALL honor an enabled manual action on the selected target during an automatic social refresh and provide visible feedback while a submitted action is pending.
#### Scenario: Save during background refresh
- **WHEN** a player taps Save while a background read is pending and repeats the tap while the save is in progress
- **THEN** the client submits the originally selected share once and displays the authoritative result.
