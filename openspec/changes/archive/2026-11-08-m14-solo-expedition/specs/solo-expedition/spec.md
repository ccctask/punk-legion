## ADDED Requirements
### Requirement: Playable persistent solo expedition
A player SHALL enter a server-authoritative expedition alone with a legal owned squad, explore resource nodes, fight staged encounters and a boss, and return to the same base account with a unique outcome.
#### Scenario: Return and deploy again
- **WHEN** the player completes exploration, receives a functional part, repairs and swaps equipment
- **THEN** the next sortie uses those same owned robots with the new loadout and the ledger records the costs and rewards.
#### Scenario: Retreat, defeat or disconnect
- **WHEN** a mission ends through retreat, defeat or expiry, or the player reconnects before expiry
- **THEN** the outcome or resumed state matches the authoritative mission, with at most one set of rewards and damage.
#### Scenario: Repeated solo progression
- **WHEN** a player runs three consecutive missions and uses the rare reward progression
- **THEN** progress is visible, duplicate result delivery cannot advance it, and a functional replacement is attainable through solo play.
