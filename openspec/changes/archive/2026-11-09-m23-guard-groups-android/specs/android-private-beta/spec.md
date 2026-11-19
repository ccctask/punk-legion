## ADDED Requirements
### Requirement: Android players can deploy a shield and command a custom group
The signed Android build SHALL support crafting a physical rivet shield, deploying the equipped crawler and recalling a mixed selection on a touch screen.
#### Scenario: Recall and issue a move
- **WHEN** the commander equips the crafted shield, deploys three robots and recalls a saved two-robot group
- **THEN** recall by itself issues no order and a subsequent move changes only the selected robots' destinations
#### Scenario: Resume the same battle
- **WHEN** the client reconnects to the same seat
- **THEN** the saved group and authoritative heading of the shielded robot are available on the Android client

