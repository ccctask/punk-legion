## ADDED Requirements

### Requirement: Readable private-base construction controls
The private base SHALL keep instructions, placement results and confirmation controls readable and reachable in the supported landscape viewport.

#### Scenario: Follow the build instruction
- **WHEN** the player opens the private base at 960×540 or 640×360 and selects a facility to build
- **THEN** the player can read the complete instruction, preview a tile and reach confirmation by vertical scrolling.

#### Scenario: Recover from rejected placement
- **WHEN** the player selects an invalid tile and then a valid one
- **THEN** the rejection reason is legible and a successful confirmation creates one facility and charges its cost once.
