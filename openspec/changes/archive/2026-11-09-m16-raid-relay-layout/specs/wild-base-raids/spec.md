## ADDED Requirements
### Requirement: Read encounters from a powered relay base
The defense view SHALL accept valid frozen private-base layouts containing power relays in the warning, live and settled phases.
#### Scenario: Inspect a defense after extending power coverage
- **WHEN** a player builds a legal relay and reopens a real defense containing that building
- **THEN** the view shows the actual defense layout and battle state, supports playback after settlement and still rejects unknown or malformed buildings.
