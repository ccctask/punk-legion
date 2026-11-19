## ADDED Requirements
### Requirement: A signed Android client supports the light wheel chassis
The Android workshop SHALL let a player refit the starting robot with the wheel chassis and deploy it in an authoritative room with its original identity.
#### Scenario: Touch refit and return to base
- **WHEN** an Android player chooses and pays for a compatible wheel refit
- **THEN** the garage shows four wheels, updated statistics and the original robot and the base offers an attainable next step
#### Scenario: Move and resume
- **WHEN** a wheeled robot receives a movement order and the player reconnects to the same mission
- **THEN** the authority and client retain the wheel chassis and original component identities through the resume

