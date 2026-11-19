## ADDED Requirements
### Requirement: Android territorial sortie supply
The signed local Android beta SHALL present the attack price and support reconnecting after spending the attacker's final energy. The signed client SHALL display only the current rustyard search status on a second search.

#### Scenario: Last energy paid once
- **WHEN** a commander starts a territorial attack on Android with one energy, reconnects and finishes
- **THEN** the same battle resumes and only one supply receipt charges that commander

#### Scenario: Search again after canceling
- **WHEN** the commander cancels rustyard matchmaking and searches again
- **THEN** the current waiting state is visible and the previous cancellation notice clears
