## ADDED Requirements

### Requirement: Two live camp entry points on server schedules
The map SHALL show the product and schedule of each live camp and route a qualified participant into the corresponding authoritative contest.

#### Scenario: Independent simultaneous windows
- **WHEN** both camps open in the same test window and distinct squads enter both
- **THEN** the server admits them to separate battles with their own objectives and settlement identifiers.

#### Scenario: Only one camp open
- **WHEN** the depot window is closed and the yard window is open
- **THEN** the depot shows its next schedule and the yard remains available under its own qualification rules.

