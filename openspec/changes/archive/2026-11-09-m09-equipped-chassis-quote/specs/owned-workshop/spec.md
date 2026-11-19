## ADDED Requirements
### Requirement: Show the installed chassis as equipped
The garage SHALL display an equipped state for the current chassis and show the transaction quote only for a different candidate chassis.
#### Scenario: Successful purchase consumes the remaining components
- **WHEN** a player refits and the selected preview now matches the equipped chassis
- **THEN** the garage shows the equipped state without an insufficient-stock warning or a further purchase quote
#### Scenario: Inspect another chassis
- **WHEN** the player selects a different chassis after the purchase
- **THEN** the garage shows its ordinary cost, compatibility and insufficient-stock feedback as applicable

