## ADDED Requirements
### Requirement: Preview fabrication cost and constraints while assembling
The workshop SHALL show the authoritative fabrication price and command cost of a valid current draft before saving and identify material, weapon recipe and hangar constraints before building.
#### Scenario: Compare a support fit and a light fit
- **WHEN** the player changes the hull or modules in the draft
- **THEN** the preview updates for that fit without mutating the account, a legal unaffordable plan can be saved, and an eligible saved fit can be built for the quoted price.
